#####################################################################
#
#  OpenBib::Handler::Apache::ManageCollection
#
#  Dieses File ist (C) 2001-2007 Oliver Flimm <flimm@openbib.org>
#
#  Dieses Programm ist freie Software. Sie koennen es unter
#  den Bedingungen der GNU General Public License, wie von der
#  Free Software Foundation herausgegeben, weitergeben und/oder
#  modifizieren, entweder unter Version 2 der Lizenz oder (wenn
#  Sie es wuenschen) jeder spaeteren Version.
#
#  Die Veroeffentlichung dieses Programms erfolgt in der
#  Hoffnung, dass es Ihnen von Nutzen sein wird, aber OHNE JEDE
#  GEWAEHRLEISTUNG - sogar ohne die implizite Gewaehrleistung
#  der MARKTREIFE oder der EIGNUNG FUER EINEN BESTIMMTEN ZWECK.
#  Details finden Sie in der GNU General Public License.
#
#  Sie sollten eine Kopie der GNU General Public License zusammen
#  mit diesem Programm erhalten haben. Falls nicht, schreiben Sie
#  an die Free Software Foundation, Inc., 675 Mass Ave, Cambridge,
#  MA 02139, USA.
#
#####################################################################

#####################################################################
# Einladen der benoetigten Perl-Module
#####################################################################

package OpenBib::Handler::Apache::ManageCollection;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Apache::Constants qw(:common M_GET);
use Apache::Reload;
use Apache::Request ();
use DBI;
use Encode 'decode_utf8';
use Log::Log4perl qw(get_logger :levels);
use POSIX;

use OpenBib::Common::Util;
use OpenBib::Config;
use OpenBib::L10N;
use OpenBib::ManageCollection::Util;
use OpenBib::Session;
use OpenBib::User;

sub handler {
    my $r=shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $config = new OpenBib::Config();
    
    my $query=Apache::Request->instance($r);

    my $status=$query->parse;

    if ($status) {
        $logger->error("Cannot parse Arguments - ".$query->notes("error-notes"));
    }

    my $session   = new OpenBib::Session({
        sessionID => $query->param('sessionID'),
    });

    my $user      = new OpenBib::User({sessionID => $session->{ID}});
    
    my $stylesheet=OpenBib::Common::Util::get_css_by_browsertype($r);

    my $database                = $query->param('database')                || '';
    my $singleidn               = $query->param('singleidn')               || '';
    my $litlistid               = $query->param('litlistid')               || '';
    my $do_collection_delentry  = $query->param('do_collection_delentry')  || '';
    my $do_collection_showcount = $query->param('do_collection_showcount') || '';
    my $do_litlist_addentry     = $query->param('do_litlist_addentry')     || '';
    my $do_addlitlist           = $query->param('do_addlitlist')           || '';
    my $title                   = $query->param('title')                   || '';
    my $action                  = $query->param('action')                  || 'show';
    my $show                    = $query->param('show')                    || 'short';
    my $type                    = $query->param('type')                    || 'HTML';
    my $littype                 = $query->param('littype')                 || 1;

    my $queryoptions_ref
        = $session->get_queryoptions($query);
    
    # Message Katalog laden
    my $msg = OpenBib::L10N->get_handle($queryoptions_ref->{l}) || $logger->error("L10N-Fehler");
    $msg->fail_with( \&OpenBib::L10N::failure_handler );
    
    # Ab hier ist in $user->{ID} entweder die gueltige Userid oder nichts, wenn
    # die Session nicht authentifiziert ist

    $logger->debug(YAML::Dump($queryoptions_ref));

    my $targetdbinfo_ref
        = $config->get_targetdbinfo();

    my $targetcircinfo_ref
        = $config->get_targetcircinfo();

    if (!$session->is_valid()){
        OpenBib::Common::Util::print_warning($msg->maketext("Ungültige Session"),$r,$msg);
        return OK;
    }

    my $view="";

    if ($query->param('view')) {
        $view=$query->param('view');
    }
    else {
        $view=$session->get_viewname();
    }

    $logger->debug(":".$user->is_authenticated.":$do_addlitlist");
    if (! $user->is_authenticated && $do_addlitlist){
        # Aufruf-URL
        my $return_url = $r->parsed_uri->unparse;

        # Return-URL in der Session abspeichern

        $session->set_returnurl($return_url);

        $logger->debug("Nicht authentifizierter Nutzer versucht Literaturliste anzulegen");
        $r->internal_redirect("http://$config->{servername}$config->{login_loc}?sessionID=$session->{ID};view=$view;do_login=1");

        return OK;
    }

    $logger->info("SessionID: $session->{ID}");
    
    my $idnresult="";

    # Einfuegen eines Titels ind die Merkliste
    if ($action eq "insert") {
        if ($user->{ID}) {
            # Zuallererst Suchen, ob der Eintrag schon vorhanden ist.
            my $idnresult=$user->{dbh}->prepare("select count(*) as rowcount from treffer where userid = ? and dbname = ? and singleidn = ?") or $logger->error($DBI::errstr);
            $idnresult->execute($user->{ID},$database,$singleidn) or $logger->error($DBI::errstr);
            my $res    = $idnresult->fetchrow_hashref;
            my $anzahl = $res->{rowcount};

            $idnresult->finish();

            if ($anzahl == 0) {
                # Zuerst Eintragen der Informationen
                my $idnresult=$user->{dbh}->prepare("insert into treffer values (?,?,?)") or $logger->error($DBI::errstr);
                $idnresult->execute($user->{ID},$database,$singleidn) or $logger->error($DBI::errstr);
                $idnresult->finish();
            }
        }
        # Anonyme Session
        else {
            $session->set_item_in_collection({
                database => $database,
                id       => $singleidn,
            });
        }

        OpenBib::Common::Util::print_info($msg->maketext("Der Titel wurde zu Ihrer Merkliste hinzugef&uuml;gt."),$r,$msg);
        return OK;
    }
    # Anzeigen des Inhalts der Merkliste
    elsif ($action eq "show") {
        if ($do_collection_showcount) {

            # Ab hier ist in $user->{ID} entweder die gueltige Userid oder nichts, wenn
            # die Session nicht authentifiziert ist
            # Dementsprechend einen LoginLink oder ein ProfilLink ausgeben
            my $anzahl="";
            
            if ($user->{ID}) {
                # Anzahl Eintraege der privaten Merkliste bestimmen
                # Zuallererst Suchen, wieviele Titel in der Merkliste vorhanden sind.
                $anzahl =    $user->get_number_of_items_in_collection();
            }
            else {
                #  Zuallererst Suchen, wieviele Titel in der Merkliste vorhanden sind.
                $anzahl = $session->get_number_of_items_in_collection();
            }

            # Start der Ausgabe mit korrektem Header
            print $r->send_http_header("text/plain");
            
            print $anzahl;

            return OK;
        }
        elsif ($do_collection_delentry) {
            foreach my $tit ($query->param('titid')) {
                my ($titdb,$titid)=split(":",$tit);
	
                if ($user->{ID}) {
                    my $idnresult=$user->{dbh}->prepare("delete from treffer where userid = ? and dbname = ? and singleidn = ?") or $logger->error($DBI::errstr);
                    $idnresult->execute($user->{ID},$titdb,$titid) or $logger->error($DBI::errstr);
                    $idnresult->finish();
                }
                else {
                    $session->clear_item_in_collection({
                        database => $titdb,
                        id       => $titid,
                    });
                }
            }

            my $redirecturl   = "http://$config->{servername}$config->{managecollection_loc}?sessionID=$session->{ID}";

            if ($view ne "") {
                $redirecturl.=";view=$view";
            }

            $r->internal_redirect($redirecturl);
            return OK;
        }
	elsif ($do_litlist_addentry) {
	  my $litlist_properties_ref = $user->get_litlist_properties({ litlistid => $litlistid});

	  foreach my $tit ($query->param('titid')) {
	    my ($titdb,$titid)=split(":",$tit);
	    
	    if ($litlist_properties_ref->{userid} eq $user->{ID}){
	      $user->add_litlistentry({ titid => $titid, titdb => $titdb, litlistid => $litlistid});
	    }
	  }

	  $r->internal_redirect("http://$config->{servername}$config->{litlists_loc}?sessionID=$session->{ID}&action=manage&litlistid=$litlistid&do_showlitlist=1");
	  return OK;

	}
	elsif ($do_addlitlist) {
	  if (!$title){
	    OpenBib::Common::Util::print_warning($msg->maketext("Sie müssen einen Titel f&uuml;r Ihre Literaturliste eingeben."),$r,$msg);
	    
	    return OK;
	  }
	  
	  $user->add_litlist({ title =>$title, type => $littype});

	  $r->internal_redirect("http://$config->{servername}$config->{managecollection_loc}?sessionID=$session->{ID}&action=show&type=HTML");
	  return OK;
	}

        # Schleife ueber alle Treffer
        my $idnresult="";

        my @dbidnlist=();
        
        if ($user->{ID}) {
            $idnresult=$user->{dbh}->prepare("select * from treffer where userid = ? order by dbname") or $logger->error($DBI::errstr);
            $idnresult->execute($user->{ID}) or $logger->error($DBI::errstr);

            while (my $result=$idnresult->fetchrow_hashref()) {
                my $database  = decode_utf8($result->{'dbname'});
                my $singleidn = decode_utf8($result->{'singleidn'});
                
                push @dbidnlist, {
                    database  => $database,
                    singleidn => $singleidn,
                };
            }

            $idnresult->finish();
        }
        else {
            push @dbidnlist, $session->get_items_in_collection();
        }

        my @collection=();

        if ($#dbidnlist < 0){
            OpenBib::Common::Util::print_warning($msg->maketext("Derzeit ist Ihre Merkliste leer"),$r,$msg);
            return OK;
        }
        
        foreach my $dbidn_ref (@dbidnlist) {
            my $database  = $dbidn_ref->{database};
            my $singleidn = $dbidn_ref->{singleidn};

            my $record = OpenBib::Record::Title->new({database=>$database})
                      ->get_full_record({id=>$singleidn});
            
            $logger->debug("Merklistensatz geholt");
  
            push @collection, {
                database => $database,
                dbdesc   => $targetdbinfo_ref->{dbinfo}{$database},
                titidn   => $singleidn,
                tit      => $record->get_normdata,
                mex      => $record->get_mexdata,
                circ     => $record->get_circdata,
            };
        }
    
        # TT-Data erzeugen
        my $ttdata={
            view              => $view,
            stylesheet        => $stylesheet,
            sessionID         => $session->{ID},
            qopts             => $queryoptions_ref,
            type              => $type,
            show              => $show,
            collection        => \@collection,
            targetdbinfo      => $targetdbinfo_ref,
            normset2bibtex    => \&OpenBib::Common::Util::normset2bibtex,

	    user              => $user,
            config            => $config,
            msg               => $msg,
        };
    
        OpenBib::Common::Util::print_page($config->{tt_managecollection_show_tname},$ttdata,$r);
        return OK;
    }
    # Abspeichern der Merkliste
    elsif ($action eq "save") {
        my @dbidnlist=();
    
        if ($singleidn && $database) {
            push @dbidnlist, {
                database  => $database,
                singleidn => $singleidn,
            };
        }
        else {
            # Schleife ueber alle Treffer
            if ($user->{ID}) {
                my $idnresult=$user->{dbh}->prepare("select * from treffer where userid = ? order by dbname") or $logger->error($DBI::errstr);
                $idnresult->execute($user->{ID}) or $logger->error($DBI::errstr);
                while (my $result=$idnresult->fetchrow_hashref()) {
                    my $database  = decode_utf8($result->{'dbname'});
                    my $singleidn = decode_utf8($result->{'singleidn'});
                    
                    push @dbidnlist, {
                        database  => $database,
                        singleidn => $singleidn,
                    };
                }
                $idnresult->finish();
            }
            else {
                push @dbidnlist, $session->get_items_in_collection();
            }
        }
        
        my @collection=();
    
        foreach my $dbidn_ref (@dbidnlist) {
            my $database  = $dbidn_ref->{database};
            my $singleidn = $dbidn_ref->{singleidn};

            my $record = OpenBib::Record::Title->new({database=>$database})
                      ->get_full_record({id=>$singleidn});
      
            $logger->info("Merklistensatz geholt");
      
            push @collection, {
                database => $database,
                dbdesc   => $targetdbinfo_ref->{dbinfo}{$database},
                titidn   => $singleidn,
                tit      => $record->get_normdata,
                mex      => $record->get_mexdata,
                circ     => $record->get_circdata,
            };
        }
    
        # TT-Data erzeugen
        my $ttdata={
            view       => $view,
            stylesheet => $stylesheet,
            sessionID  => $session->{ID},
            qopts      => $queryoptions_ref,		
            type       => $type,
            show       => $show,
            collection => \@collection,
            normset2bibtex    => \&OpenBib::Common::Util::normset2bibtex,

            config     => $config,
            msg        => $msg,
        };
    
        if ($type eq "HTML") {
      
            print $r->header_out("Content-Type" => "text/html");
            print $r->header_out("Content-Disposition" => "attachment;filename=\"kugliste.html\"");
            OpenBib::Common::Util::print_page($config->{tt_managecollection_save_html_tname},$ttdata,$r);
        }
        else {
            print $r->header_out("Content-Type" => "text/plain");
            print $r->header_out("Content-Disposition" => "attachment;filename=\"kugliste.txt\"");
            OpenBib::Common::Util::print_page($config->{tt_managecollection_save_plain_tname},$ttdata,$r);
        }
        return OK;
    }
    # Verschicken der Merkliste per Mail
    elsif ($action eq "mail") {
        # Weg mit der Singleidn - muss spaeter gefixed werden
        my $userresult=$user->{dbh}->prepare("select loginname from user where userid = ?") or $logger->error($DBI::errstr);
        $userresult->execute($user->{ID}) or $logger->error($DBI::errstr);
    
        my $loginname="";
    
        while(my $res=$userresult->fetchrow_hashref()){
            $loginname = decode_utf8($res->{'loginname'});
        }

        my @dbidnlist=();
        if ($singleidn && $database) {
            push @dbidnlist, {
                database  => $database,
                singleidn => $singleidn,
            };
        }
        else {
            # Schleife ueber alle Treffer
            if ($user->{ID}) {
                my $idnresult=$user->{dbh}->prepare("select * from treffer where userid = ? order by dbname") or $logger->error($DBI::errstr);
                $idnresult->execute($user->{ID}) or $logger->error($DBI::errstr);

                while (my $result=$idnresult->fetchrow_hashref()) {
                    my $database  = decode_utf8($result->{'dbname'});
                    my $singleidn = decode_utf8($result->{'singleidn'});
                    
                    push @dbidnlist, {
                        database  => $database,
                        singleidn => $singleidn,
                    };
                }
                
                $idnresult->finish();
            }
            else {
                push @dbidnlist, $session->get_items_in_collection();
            }

        }

        my @collection=();
    
        foreach my $dbidn_ref (@dbidnlist) {
            my $database  = $dbidn_ref->{database};
            my $singleidn = $dbidn_ref->{singleidn};

            my $record = OpenBib::Record::Title->new({database=>$database})
                      ->get_full_record({id=>$singleidn});
      
            $logger->debug("Merklistensatz geholt");
      
            push @collection, {
                database => $database,
                dbdesc   => $targetdbinfo_ref->{dbinfo}{$database},
                titidn   => $singleidn,
                tit      => $record->get_normdata,
                mex      => $record->get_mexdata,
                circ     => $record->get_circdata,
            };
        }
    
        # TT-Data erzeugen
        my $ttdata={
            view       => $view,
            stylesheet => $stylesheet,
            sessionID  => $session->{ID},
            qopts      => $queryoptions_ref,				
            type       => $type,
            show       => $show,
            loginname  => $loginname,
            singleidn  => $singleidn,
            database   => $database,
            collection => \@collection,
            normset2bibtex    => \&OpenBib::Common::Util::normset2bibtex,

            config     => $config,
            msg        => $msg,
        };
    
        OpenBib::Common::Util::print_page($config->{tt_managecollection_mail_tname},$ttdata,$r);
        return OK;
    }
    # Ausdrucken der Merkliste (HTML) ueber Browser
    elsif ($action eq "print") {
        # Weg mit der Singleidn - muss spaeter gefixed werden
        my $userresult=$user->{dbh}->prepare("select loginname from user where userid = ?") or $logger->error($DBI::errstr);
        $userresult->execute($user->{ID}) or $logger->error($DBI::errstr);
    
        my $loginname="";
    
        while(my $res=$userresult->fetchrow_hashref()){
            $loginname = decode_utf8($res->{'loginname'});
        }
    
        my @dbidnlist=();
        if ($singleidn && $database) {
            push @dbidnlist, {
                database  => $database,
                singleidn => $singleidn,
            };
        }
        else {
            # Schleife ueber alle Treffer
            if ($user->{ID}) {
                my $idnresult=$user->{dbh}->prepare("select * from treffer where userid = ? order by dbname") or $logger->error($DBI::errstr);
                $idnresult->execute($user->{ID}) or $logger->error($DBI::errstr);
                while (my $result=$idnresult->fetchrow_hashref()) {
                    my $database  = decode_utf8($result->{'dbname'});
                    my $singleidn = decode_utf8($result->{'singleidn'});
                    
                    push @dbidnlist, {
                        database  => $database,
                        singleidn => $singleidn,
                    };
                }
                $idnresult->finish();
            }
            else {
                push @dbidnlist, $session->get_items_in_collection();
            }
        }

        my @collection=();
    
        foreach my $dbidn_ref (@dbidnlist) {
            my $database  = $dbidn_ref->{database};
            my $singleidn = $dbidn_ref->{singleidn};

            my $record = OpenBib::Record::Title->new({database=>$database})
                      ->get_full_record({id=>$singleidn});
      
            $logger->info("Merklistensatz geholt");
      
            push @collection, {
                database => $database,
                dbdesc   => $targetdbinfo_ref->{dbinfo}{$database},
                titidn   => $singleidn,
                tit      => $record->get_normdata,
                mex      => $record->get_mexdata,
                circ     => $record->get_circdata,
            };
        }
    
        # TT-Data erzeugen
        my $ttdata={
            view       => $view,
            stylesheet => $stylesheet,		
            sessionID  => $session->{ID},
            qopts      => $queryoptions_ref,		
            type       => $type,
            show       => $show,
            loginname  => $loginname,
            singleidn  => $singleidn,
            database   => $database,
            collection => \@collection,
            normset2bibtex    => \&OpenBib::Common::Util::normset2bibtex,

            config     => $config,
            msg        => $msg,
        };
    
        OpenBib::Common::Util::print_page($config->{tt_managecollection_print_tname},$ttdata,$r);
        return OK;
    }
    return OK;
}

1;