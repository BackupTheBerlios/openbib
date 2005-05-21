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

use Apache::Constants qw(:common);

use strict;
use warnings;
no warnings 'redefine';

use Apache::Request();      # CGI-Handling (or require)

use Log::Log4perl qw(get_logger :levels);

use Template;

use DBI;

use SOAP::Lite;

use OpenDIA::Collections;
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
  
  my $metadbh=DBI->connect("DBI:$config{dbimodule}:dbname=$config{metadbname};host=$config{metadbhost};port=$config{metadbport}", $config{metadbuser}, $config{metadbpasswd}) or $logger->error_die($DBI::errstr);

  my $template = Template->new({ 
				INCLUDE_PATH  => $config{tt_include_path},
				#    	    PRE_PROCESS   => 'config',
				OUTPUT        => $r,     # Output geht direkt an Apache Request
			       });

  my $query=Apache::Request->new($r);

  my $collection=$query->param('collection') || '';
  my $action=$query->param('action') || '';
  my $item=$query->param('item') || '';
  my $sub=$query->param('sub') || '';
  my $sub1=$query->param('sub1') || '';
  my $sub2=$query->param('sub2') || '';
  my $image=$query->param('image') || '';
  my $meta=$query->param('meta') || 'dc';
  
  if ($action eq "showcolls"){

    my $request=$metadbh->prepare("select distinct collection from meta");
    $request->execute();
    
    my @collections;

    while (my $result=$request->fetchrow_hashref()){

      my %singleinfo=();
      $singleinfo{name}=$result->{collection};
      
      my $request2=$metadbh->prepare("select category,content from meta where collection=? and item='';");
      $request2->execute($result->{collection});

      while (my $result2=$request2->fetchrow_hashref()){
	my $category=$result2->{category};
	my $content=$result2->{content};
	$singleinfo{meta}{$category}=$content;
      }

      push @collections, \%singleinfo;
    }

    # TT-Data erzeugen
    
    my $ttdata={
		collections   => \@collections,
		config       => \%config,
	       };
    
    # Dann Ausgabe des neuen Headers
    
    print $r->send_http_header("text/html");
    
    $template->process($config{tt_viewer_showallcolls_tname}, $ttdata) || do { 
      $r->log_reason($template->error(), $r->filename);
      return SERVER_ERROR;
    };
    
    return OK;
    
  }
  elsif ($action eq "showsinglecoll"){

    my $request=$metadbh->prepare("select distinct item from meta where collection=? and item != ''");
    $request->execute($collection);
    
    my @items;

    while (my $result=$request->fetchrow_hashref()){

      my %singleinfo=();
      $singleinfo{name}=$result->{item};

      my $request2=$metadbh->prepare("select category,content from meta where collection=? and item=? and sub='' and type='orgunit'");
      $request2->execute($collection,$result->{item});

      while (my $result2=$request2->fetchrow_hashref()){
	$singleinfo{meta}{$result2->{category}}=$result2->{content};
      }

      push @items, \%singleinfo;
    }

    
    # TT-Data erzeugen
    
    my $ttdata={
		items      => \@items,
		collection   => $collection,
		config       => \%config,
	       };
    
    # Dann Ausgabe des neuen Headers
    
    print $r->send_http_header("text/html");
    
    $template->process($config{tt_viewer_showsinglecoll_tname}, $ttdata) || do { 
      $r->log_reason($template->error(), $r->filename);
      return SERVER_ERROR;
    };
    
    return OK;
    
  }
  else {

    $r->internal_redirect("http://$config{servername}$config{viewer_loc}?action=showcolls");
    
    return OK;
  }

}

1;
