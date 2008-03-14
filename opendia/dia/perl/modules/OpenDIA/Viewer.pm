#####################################################################
#
#  OpenDIA::Viewer
#
#  Dieses File ist (C) 2005 Oliver Flimm <flimm@openbib.org>
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

package OpenDIA::Viewer;

use strict;
use warnings;
no warnings 'redefine';

use Apache::Constants qw(:common);
use Apache::Request ();
use Encode;
use DBI;
use Log::Log4perl qw(get_logger :levels);
use SOAP::Lite;
use Template;
use YAML;

use OpenDIA::Collections;
use OpenDIA::Common::Util;
use OpenDIA::Config;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace
use vars qw(%config);

*config=\%OpenDIA::Config::config;

sub handler {
    my $r=shift;
  
    # Log4perl logger erzeugen
    my $logger = get_logger();

    # Verbindung zur SQL-Datenbank herstellen
    my $metadbh
        = DBI->connect("DBI:$config{dbimodule}:dbname=$config{metadbname};host=$config{metadbhost};port=$config{metadbport}", $config{metadbuser}, $config{metadbpasswd})
            or $logger->error_die($DBI::errstr);

    my $template = Template->new({ 
        INCLUDE_PATH  => $config{tt_include_path},
        OUTPUT        => $r,    # Output geht direkt an Apache Request
    });

    my $query=Apache::Request->new($r);

    my $collection        = $query->param('collection')        || '';
    my $action            = $query->param('action')            || '';
    my $subaction         = $query->param('subaction')         || '';
    my $item              = $query->param('item')              || '';
    my $sub               = $query->param('sub')               || '';
    my $sub1              = $query->param('sub1')              || '';
    my $sub2              = $query->param('sub2')              || '';
    my $image             = $query->param('image')             || '';
    my $meta              = $query->param('meta')              || 'dc';
    my $browsebb          = $query->param('browsebb')          || '';
    my $browseeinband     = $query->param('browseeinband')     || '';
    my $browsejahrhundert = $query->param('browsejahrhundert') || '';
    my $browseregion      = $query->param('browseregion')      || '';

    my $browsecat         = $query->param('browsecat')         || 'M0101';
    my $browsecontent     = $query->param('browsecontent')     || '';

    my $view              = $query->param('view')              || '';
    my $sessionID         = $query->param('sessionID')         || '';
    my $remotehost        = $query->param('remotehost')        || '';
    my $remoteview        = $query->param('remoteview')        || '';

    my $stylesheet=OpenDIA::Common::Util::get_css_by_browsertype($r);

    if ($action eq "showcolls") {
        my $request=$metadbh->prepare("select distinct collection from meta");
        $request->execute();
    
        my @collections;

        while (my $result=$request->fetchrow_hashref()) {

            my %singleinfo=();
            $singleinfo{name}=$result->{collection};
      
            my $request2=$metadbh->prepare("select category,content from meta where collection=? and item='' and metascheme != ''");
            $request2->execute($result->{collection});

            while (my $result2=$request2->fetchrow_hashref()) {
                my $category=$result2->{category};
                my $content=$result2->{content};
                $singleinfo{meta}{$category}=$content;
            }

            push @collections, \%singleinfo;
        }

        # TT-Data erzeugen
        my $ttdata={
            view        => $view,
            stylesheet  => $stylesheet,
            collections => \@collections,
            config      => \%config,
        };
    
        # Dann Ausgabe des neuen Headers
        print $r->send_http_header("text/html");
    
        $template->process($config{tt_viewer_showallcolls_tname}, $ttdata) || do { 
            $r->log_reason($template->error(), $r->filename);
            return SERVER_ERROR;
        };
    
        return OK;
    
    }
    elsif ($action eq "showsinglecoll") {
        if ($subaction eq "searchmask") {
            my @items;
      
            # TT-Data erzeugen
      
            my $ttdata={
                view       => $view,
                stylesheet => $stylesheet,
                items      => \@items,
                collection => $collection,
                config     => \%config,

            };

            OpenDIA::Common::Util::print_page($config{tt_viewer_showsinglecoll_searchmask_tname},$ttdata,$r);
      
            return OK;
      
        }
        elsif ($subaction eq "browsemask") {
            my @items;
      
            # TT-Data erzeugen
            my $ttdata={
                view       => $view,
                stylesheet => $stylesheet,
                items      => \@items,
                collection => $collection,
                remotehost => $remotehost,
                remoteview => $remoteview,
                sessionID  => $sessionID,

                config     => \%config,

            };


            OpenDIA::Common::Util::print_page($config{tt_viewer_showsinglecoll_browsemask_tname},$ttdata,$r);
      
            return OK;
      
        }
        else {
            my $request=$metadbh->prepare("select distinct item from meta where collection=? and item != ''");
            $request->execute($collection);
      
            my @items;
      
            while (my $result=$request->fetchrow_hashref()) {
	
                my %singleinfo=();
                $singleinfo{name}=$result->{item};
	
                my $request2=$metadbh->prepare("select category,content from meta where collection=? and item=? and sub='' and type='orgunit'");
                $request2->execute($collection,$result->{item});
	
                while (my $result2=$request2->fetchrow_hashref()) {
                    $singleinfo{meta}{$result2->{category}}=$result2->{content};
                }
	
                push @items, \%singleinfo;
            }
      
            $logger->info("Showsinglecol-Items".YAML::Dump(\@items));
      
            # TT-Data erzeugen
            my $ttdata={
                view       => $view,
                stylesheet => $stylesheet,
                items      => \@items,
                collection => $collection,
                remotehost => $remotehost,
                remoteview => $remoteview,
                sessionID  => $sessionID,
                config     => \%config,
            };
      
            # Dann Ausgabe des neuen Headers
      
            print $r->send_http_header("text/html");
      
            $template->process($config{tt_viewer_showsinglecoll_tname}, $ttdata) || do { 
                $r->log_reason($template->error(), $r->filename);
                return SERVER_ERROR;
            };
      
        } 
   
        return OK;
    
    }
    elsif ($action eq "showsingleitem") {
        my @iteminfos=();
        push @iteminfos, OpenDIA::Common::Util::getMetaFromDB($metadbh,$collection,$item);

        $logger->info("Showsingleitem:".YAML::Dump(\@iteminfos));
        
        # TT-Data erzeugen
    
        my $ttdata={
            view       => $view,
            stylesheet => $stylesheet,
            item       => $item,
            iteminfos  => \@iteminfos,
            collection => $collection,
            remotehost => $remotehost,
            remoteview => $remoteview,
            sessionID  => $sessionID,
            config     => \%config,
        };

        OpenDIA::Common::Util::print_page($config{tt_viewer_showsingleitem_tname},$ttdata,$r);
    
        return OK;
    }


    ######################################################################

    elsif ($action eq "browse") {
        if ($browsecontent) {
            my $request=$metadbh->prepare("select distinct item from meta where collection=? and item != '' and type='orgunit' and category=? and content=?");
            $request->execute($collection,$browsecat,$browsecontent);
      
            my @iteminfos=();
      
            while (my $result=$request->fetchrow_hashref()) {
                my $item=$result->{item};
                push @iteminfos, OpenDIA::Common::Util::getMetaFromDB($metadbh,$collection,$item);
            }


            $logger->info("Browsecontent:".YAML::Dump(\@iteminfos));
            
            # Sortierung nach Fertigungsjahr

            my @sortediteminfos
                = map { $_->[0] }
                  sort by_year
                  map { [$_, grepCategory($_->{meta},'M0424')] } @iteminfos;

            # TT-Data erzeugen
            my $ttdata={
                view          => $view,
                stylesheet    => $stylesheet,
                browsecat     => $browsecat,
                browsecontent => $browsecontent,
                iteminfos     => \@sortediteminfos,
                collection    => $collection,
                remotehost    => $remotehost,
                remoteview    => $remoteview,
                sessionID     => $sessionID,

                iso2utf8      => sub {
                    my $string=shift;
                    $string=Encode::encode_utf8($string);
                    return $string;
                },

                config        => \%config,
            };
      
            OpenDIA::Common::Util::print_page($config{tt_viewer_browsecontent_tname},$ttdata,$r);
      
            return OK;
        }
        else {
            my $request=$metadbh->prepare("select distinct content from meta where collection=? and item != '' and type='orgunit' and category=?");
            $request->execute($collection,$browsecat);
      
            my @items;
      
            while (my $result=$request->fetchrow_hashref()) {

                push @items, {
                    plain  => $result->{content},
                    webarg => OpenDIA::Common::Util::convweb( $result->{content} ),
                };
            }
      
            my @sorteditems=sort { OpenDIA::Common::Util::normalize($a->{plain}) cmp OpenDIA::Common::Util::normalize($b->{plain}) } @items;

            $logger->info("Showsinglecol-Items".YAML::Dump(\@sorteditems));
      
            # TT-Data erzeugen
            my $ttdata={
                view       => $view,
                stylesheet => $stylesheet,
                browsecat  => $browsecat,
                items      => \@sorteditems,
                collection => $collection,
                remotehost => $remotehost,
                remoteview => $remoteview,
                sessionID  => $sessionID,

                iso2utf8      => sub {
                    my $string=shift;
                    $string=Encode::encode_utf8($string);
                    return $string;
                },

                config     => \%config,
            };
      
            OpenDIA::Common::Util::print_page($config{tt_viewer_browse_tname},$ttdata,$r);
      
            return OK;
        }
    }
    else {
        $r->internal_redirect("http://$config{servername}$config{viewer_loc}?action=showcolls");
    
        return OK;
    }
}

sub grepCategory {
    my ($meta_ref,$category)=@_;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    foreach my $cat (@{$meta_ref}){
        if ($cat->{category} eq $category){
            my $content=$cat->{content};

            $logger->info("Category: $category Content:".$content);

#            if (OpenDIA::Common::Util::category_is_numeric($collection,$format,$category)){
#                ($content)=$content=~m/(\d\d\d\d)/;
#            }

            return $content;
        }       

    }   
    return;
}

sub by_year {
    my @line1=@$a;
    my @line2=@$b;
    
    $line1[1]=0 if ($line1[1] eq "");
    $line2[1]=0 if ($line2[1] eq "");
    
    ($line1[1])=$line1[1]=~m/(\d\d\d\d)/;
    ($line2[1])=$line2[1]=~m/(\d\d\d\d)/;
    
    $line1[1] <=> $line2[1];
}

1;
