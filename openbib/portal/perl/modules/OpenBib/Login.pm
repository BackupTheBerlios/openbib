#####################################################################
#
#  OpenBib::Login
#
#  Dieses File ist (C) 2004-2006 Oliver Flimm <flimm@openbib.org>
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

package OpenBib::Login;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Apache::Constants qw(:common);
use Apache::Reload;
use Apache::Request ();
use DBI;
use Digest::MD5;
use Encode 'decode_utf8';
use Log::Log4perl qw(get_logger :levels);
use POSIX;
use Socket;
use Template;

use OpenBib::Common::Util;
use OpenBib::Config;
use OpenBib::Login::Util;
use OpenBib::L10N;
use OpenBib::Session;

sub handler {
    my $r=shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $config = new OpenBib::Config();
    
    my $query=Apache::Request->new($r);

    my $status=$query->parse;

    if ($status) {
        $logger->error("Cannot parse Arguments - ".$query->notes("error-notes"));
    }

    my $session   = new OpenBib::Session({
        sessionID => $query->param('sessionID'),
    });

    my $stylesheet=OpenBib::Common::Util::get_css_by_browsertype($r);

    # Standardwerte festlegen
    my $action    = ($query->param('action'))?$query->param('action'):'none';
    my $code      = ($query->param('code'))?$query->param('code'):'1';
    my $targetid  = ($query->param('targetid'))?$query->param('targetid'):'none';
    my $loginname = ($query->param('loginname'))?$query->param('loginname'):'';
    my $password  = ($query->param('password'))?$query->param('password'):'';

    # Main-Actions
    my $do_login       = $query->param('do_login')        || '';
    my $do_auth        = $query->param('do_auth' )        || '';
    my $do_loginfailed = $query->param('do_loginfailed')  || '';
    
    my $userdbh
        = DBI->connect("DBI:$config->{dbimodule}:dbname=$config->{userdbname};host=$config->{userdbhost};port=$config->{userdbport}", $config->{userdbuser}, $config->{userdbpasswd})
            or $logger->error_die($DBI::errstr);

    my $queryoptions_ref
        = $session->get_queryoptions($query);
    
    # Message Katalog laden
    my $msg = OpenBib::L10N->get_handle($queryoptions_ref->{l}) || $logger->error("L10N-Fehler");
    $msg->fail_with( \&OpenBib::L10N::failure_handler );

    if (!$session->is_valid()){
        OpenBib::Common::Util::print_warning($msg->maketext("Ungültige Session"),$r,$msg);
        $userdbh->disconnect();

        return OK;
    }

    my $view="";

    if ($query->param('view')) {
        $view=$query->param('view');
    }
    else {
        $view=$session->get_viewname();
    }
  
    if ($do_login) {
        my $targetresult=$userdbh->prepare("select * from logintarget order by type DESC,description") or $logger->error($DBI::errstr);
        $targetresult->execute() or $logger->error($DBI::errstr);
    
        my $targetselect="<select name=\"targetid\">";
        while (my $result=$targetresult->fetchrow_hashref()) {
            my $targetid    = decode_utf8($result->{'targetid'});
            my $description = decode_utf8($result->{'description'});

            $targetselect.="<option value=\"$targetid\">$description</option>";
        }
        $targetselect.="</select>";
        $targetresult->finish();
    
        # TT-Data erzeugen
        my $ttdata={
            view         => $view,
            stylesheet   => $stylesheet,
            sessionID    => $session->{ID},
            targetselect => $targetselect,
            loginname    => $loginname,
            config       => $config,
            msg          => $msg,
        };
    
        OpenBib::Common::Util::print_page($config->{tt_login_tname},$ttdata,$r);
    }
    elsif ($do_auth) {
        my $loginfailed=0;
    
        if ($loginname eq "" || $password eq "") {
            $loginfailed=1;
        }
   
        my $targetresult=$userdbh->prepare("select * from logintarget where targetid = ?") or $logger->error($DBI::errstr);
        $targetresult->execute($targetid) or $logger->error($DBI::errstr);
    
        my $hostname    = "";
        my $port        = "";
        my $user        = "";
        my $db          = "";
        my $description = "";
        my $type        = "";
  
        while (my $result=$targetresult->fetchrow_hashref()) {
            $hostname    = decode_utf8($result->{'hostname'});
            $port        = decode_utf8($result->{'port'});
            $user        = decode_utf8($result->{'user'});
            $db          = decode_utf8($result->{'db'});
            $description = decode_utf8($result->{'description'});
            $type        = decode_utf8($result->{'type'});
        }

        $targetresult->finish();

        ## Ausleihkonfiguration fuer den Katalog einlesen
        my $targetcircinfo_ref
            = $config->get_targetcircinfo();

        if ($type eq "olws") {
        
            my $userinfo_ref=OpenBib::Login::Util::authenticate_olws_user({
                username      => $loginname,
                pin           => $password,
                circhcheckurl => $targetcircinfo_ref->{$db}{circcheckurl},
                circdb        => $targetcircinfo_ref->{$db}{circdb},
            });
        
            my %userinfo=%$userinfo_ref;
      
            if ($userinfo{'erfolgreich'} ne "1") {
                $loginfailed=2;
            }
      
            # Gegebenenfalls Benutzer lokal eintragen
            else {
                my $userid;

                my $userresult=$userdbh->prepare("select count(userid) as rowcount from user where loginname = ?") or $logger->error($DBI::errstr);
                $userresult->execute($loginname) or $logger->error($DBI::errstr);
                my $res=$userresult->fetchrow_hashref;
                my $rows=$res->{rowcount};

                # Eintragen, wenn noch nicht existent
                if ($rows <= 0) {
                    # Neuen Satz eintragen
                    $userresult=$userdbh->prepare("insert into user values (NULL,'',?,?,'','','','',0,'','','','','','','','','','','','','')") or $logger->error($DBI::errstr);
                    $userresult->execute($loginname,$password) or $logger->error($DBI::errstr);
                }
                else {
                    # Neuen Satz eintragen
                    $userresult=$userdbh->prepare("update user set pin = ? where loginname = ?") or $logger->error($DBI::errstr);
                    $userresult->execute($password,$loginname) or $logger->error($DBI::errstr);
                }

                # Benuzerinformationen eintragen
                $userresult=$userdbh->prepare("update user set nachname = ?, vorname = ?, strasse = ?, ort = ?, plz = ?, soll = ?, gut = ?, avanz = ?, branz = ?, bsanz = ?, vmanz = ?, maanz = ?, vlanz = ?, sperre = ?, sperrdatum = ?, gebdatum = ? where loginname = ?") or $logger->error($DBI::errstr);
                $userresult->execute($userinfo{'Nachname'},$userinfo{'Vorname'},$userinfo{'Strasse'},$userinfo{'Ort'},$userinfo{'PLZ'},$userinfo{'Soll'},$userinfo{'Guthaben'},$userinfo{'Avanz'},$userinfo{'Branz'},$userinfo{'Bsanz'},$userinfo{'Vmanz'},$userinfo{'Maanz'},$userinfo{'Vlanz'},$userinfo{'Sperre'},$userinfo{'Sperrdatum'},$userinfo{'Geburtsdatum'},$loginname) or $logger->error($DBI::errstr);
                $userresult->finish();
            }
        }
        elsif ($type eq "self") {
            my $result=OpenBib::Login::Util::authenticate_self_user({
                username  => $loginname,
                pin       => $password,
                userdbh   => $userdbh,
                sessionID => $session->{ID},
            });
      
            if ($result <= 0) {
                $loginfailed=2;
            }
        }
        else {
            $loginfailed=2;
        }
    
        if (!$loginfailed) {
            # Jetzt wird die Session mit der Benutzerid assoziiert
            my $userresult=$userdbh->prepare("select userid from user where loginname = ?") or $logger->error($DBI::errstr);
            $userresult->execute($loginname) or $logger->error($DBI::errstr);
      
            my $res=$userresult->fetchrow_hashref();
            my $userid = decode_utf8($res->{'userid'});

            # Es darf keine Session assoziiert sein. Daher stumpf loeschen
            my $globalsessionID="$config->{servername}:$session->{ID}";
            $userresult=$userdbh->prepare("delete from usersession where sessionid = ?") or $logger->error($DBI::errstr);
            $userresult->execute($globalsessionID) or $logger->error($DBI::errstr);
      
            $userresult=$userdbh->prepare("insert into usersession values (?,?,?)") or $logger->error($DBI::errstr);
            $userresult->execute($globalsessionID,$userid,$targetid) or $logger->error($DBI::errstr);
      
            # Ueberpruefen, ob der Benutzer schon ein Suchprofil hat
            $userresult=$userdbh->prepare("select count(userid) as rowcount from fieldchoice where userid = ?") or $logger->error($DBI::errstr);
            $userresult->execute($userid) or $logger->error($DBI::errstr);
            $res=$userresult->fetchrow_hashref;

            my $rows=$res->{rowcount};

            # Falls noch keins da ist, eintragen
            if ($rows <= 0) {
                $userresult=$userdbh->prepare("insert into fieldchoice values (?,1,1,1,1,1,1,1,1,1,1,0,1)") or $logger->error($DBI::errstr);
                $userresult->execute($userid) or $logger->error($DBI::errstr);
            }
      
            # Jetzt wird die bestehende Trefferliste uebernommen.
            # Gehe ueber alle Eintraege der Trefferliste
            my $idnresult=$session->{dbh}->prepare("select dbname,singleidn from treffer where sessionid = ?") or $logger->error($DBI::errstr);
            $idnresult->execute($session->{ID}) or $logger->error($DBI::errstr);
      
            while (my $res=$idnresult->fetchrow_hashref()) {
                my $dbname    = decode_utf8($res->{'dbname'});
                my $singleidn = decode_utf8($res->{'singleidn'});
                
                # Zuallererst Suchen, ob der Eintrag schon vorhanden ist.
                $userresult=$userdbh->prepare("select count(userid) as rowcount from treffer where userid = ? and dbname = ? and singleidn = ?") or $logger->error($DBI::errstr);
                $userresult->execute($userid,$dbname,$singleidn) or $logger->error($DBI::errstr);
                my $res  = $userresult->fetchrow_hashref;
                my $rows = $res->{rowcount};
                if ($rows <= 0) {
                    $userresult=$userdbh->prepare("insert into treffer values (?,?,?)") or $logger->error($DBI::errstr);
                    $userresult->execute($userid,$dbname,$singleidn) or $logger->error($DBI::errstr);
                }
            }
            
            # Bestimmen des Recherchemasken-Typs
            $userresult=$userdbh->prepare("select masktype from user where userid = ?") or $logger->error($DBI::errstr);
            $userresult->execute($userid) or $logger->error($DBI::errstr);
      
            my $maskresult=$userresult->fetchrow_hashref();
            my $setmask = decode_utf8($maskresult->{'masktype'});

            # Assoziieren des Recherchemasken-Typs mit der Session
            if ($setmask ne "simple" && $setmask ne "advanced") {
                $setmask="simple";
            }

            $session->set_mask($setmask);

            $idnresult->finish();
            $userresult->finish();
        }

        # Und nun wird ein komplett neue Frameset aufgebaut
        my $headerframeurl
            = "http://$config->{servername}$config->{headerframe_loc}?sessionID=$session->{ID}";
        my $bodyframeurl
            = "http://$config->{servername}$config->{userprefs_loc}?sessionID=$session->{ID}&action=showfields";
    
        if ($view ne "") {
            $headerframeurl.="&view=$view";
            $bodyframeurl.="&view=$view";
        }

        # Fehlerbehandlung
        if ($loginfailed) {
            $bodyframeurl="http://$config->{servername}$config->{login_loc}?sessionID=$session->{ID}&do_loginfailed=1&code=$loginfailed";
        }
    
        my $ttdata={
            headerframeurl  => $headerframeurl,
            bodyframeurl    => $bodyframeurl,
            view            => $view,
            sessionID       => $session->{ID},
            config          => $config,
            msg             => $msg,
        };
    
        OpenBib::Common::Util::print_page($config->{tt_startopac_tname},$ttdata,$r);
    }
    elsif ($do_loginfailed) {
        if    ($code eq "1") {
            OpenBib::Common::Util::print_warning($msg->maketext("Sie haben entweder kein Passwort oder keinen Loginnamen eingegeben"),$r,$msg);
        }
        elsif ($code eq "2") {
            OpenBib::Common::Util::print_warning($msg->maketext("Sie konnten mit Ihrem angegebenen Benutzernamen und Passwort nicht erfolgreich authentifiziert werden"),$r,$msg);
        }
        else {
            OpenBib::Common::Util::print_warning($msg->maketext("Falscher Fehler-Code"),$r,$msg);
        }
    }

    $userdbh->disconnect();

    return OK;
}

1;
