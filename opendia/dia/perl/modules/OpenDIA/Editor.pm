#####################################################################
#
#  OpenDIA::Editor
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

package OpenDIA::Editor;

use Apache::Constants qw(:common);

use strict;
use warnings;
no warnings 'redefine';

use Apache::Request();      # CGI-Handling (or require)

use Log::Log4perl qw(get_logger :levels);

use Template;

use Image::Magick;

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

  my $template = Template->new({ 
				INCLUDE_PATH  => $config{tt_include_path},
				OUTPUT        => $r,     # Output geht direkt an Apache Request
			       });

  my $query=Apache::Request->new($r);

  my $collection=$query->param('collection') || '';
  my $action=$query->param('action') || '';
  my $item=$query->param('item') || 0;
  my $sub=$query->param('sub') || 0;
  my $sub1=$query->param('sub1') || 0;
  my $sub2=$query->param('sub2') || 0;
  my $image=$query->param('image') || '';
  my $meta=$query->param('meta') || 'dc';

  if (!$collection){
    
    my @collections=OpenDIA::Collections::get_collections();

    # TT-Data erzeugen
  
    my $ttdata={
		collections  => \@collections,
		config       => \%config,
	       };
    
    # Dann Ausgabe des neuen Headers
    
    print $r->send_http_header("text/html");
    
    $template->process($config{tt_editor_showallcolls_tname}, $ttdata) || do { 
      $r->log_reason($template->error(), $r->filename);
      return SERVER_ERROR;
    };
  
    return OK;
    
  }
  else {
    if (!OpenDIA::Collections::collection_is_valid($collection)){
      
      # TT-Data erzeugen
      
      my $ttdata={
		  errmsg       => "Digitalisat-Serie nicht g&uuml;ltig",
		  config       => \%config,
		 };
      
      # Dann Ausgabe des neuen Headers
      
      print $r->send_http_header("text/html");
      
      $template->process($config{tt_error_tname}, $ttdata) || do { 
	$r->log_reason($template->error(), $r->filename);
	return SERVER_ERROR;
      };
      
      return OK;
    }
    
  }
  
  if ($action eq "choosecollection"){

    my @items=OpenDIA::Collections::get_items($collection);
    
    # TT-Data erzeugen
    
    my $ttdata={
		items      => \@items,
		collection   => $collection,
		config       => \%config,
	       };
    
    # Dann Ausgabe des neuen Headers
    
    print $r->send_http_header("text/html");
    
    $template->process($config{tt_editor_showsinglecoll_tname}, $ttdata) || do { 
      $r->log_reason($template->error(), $r->filename);
      return SERVER_ERROR;
    };
    
    return OK;
    
  }
  elsif ($action eq "showitem"){

    my @iteminfo=OpenDIA::Collections::analyze_item($collection,$item);
    
    # TT-Data erzeugen
    
    my $ttdata={
		item       => $item,
		iteminfo      => \@iteminfo,
		collection   => $collection,
		config       => \%config,
	       };
    
    # Dann Ausgabe des neuen Headers
    
    print $r->send_http_header("text/html");
    
    $template->process($config{tt_editor_showsingleitem_tname}, $ttdata) || do { 
      $r->log_reason($template->error(), $r->filename);
      return SERVER_ERROR;
    };
    
    return OK;
    
  }
  elsif ($action eq "genthumbs"){

    my $itembasedir=$config{collection_base_dir}."/$collection/$item";

    my @iteminfo=OpenDIA::Collections::analyze_item($collection,$item);

    foreach my $img (@iteminfo){
      my ($front,$ext)=$img->{name}=~m/^(.+?)\.(...)$/;

#      unlink "$itembasedir/".$img->{thumb}  if ($img->{thumb});
      next if ($img->{thumb});

      my $image=new Image::Magick;
      $image->Read("$itembasedir/".$img->{name});
      $image->Resize(geometry => '100x100>');
      $image->Write("jpg:$itembasedir/$front"."_thumb.jpg");
    }

    $r->internal_redirect("http://$config{servername}$config{editor_loc}?action=showitem;collection=$collection;item=$item");
    
    return OK;
    
  }
  elsif ($action eq "genweb"){

    my $itembasedir=$config{collection_base_dir}."/$collection/$item";

    my @iteminfo=OpenDIA::Collections::analyze_item($collection,$item);

    foreach my $img (@iteminfo){
      my ($front,$ext)=$img->{name}=~m/^(.+?)\.(...)$/;

#      unlink "$itembasedir/".$img->{web} if ($img->{web});
      next if ($img->{web});

      my $image=new Image::Magick;
      $image->Read("$itembasedir/".$img->{name});
      $image->Resize(geometry => '1024x1024>');
      $image->Write("jpg:$itembasedir/$front"."_web.jpg");
    }

    $r->internal_redirect("http://$config{servername}$config{editor_loc}?action=showitem;collection=$collection;item=$item");
    
    return OK;
    
  }
  elsif ($action eq "editmeta"){

    my $subpath="";
    if ($sub){
      $subpath=$subpath."/".$sub;
    }
    if ($sub1){
      $subpath=$subpath."/".$sub1;
    }
    if ($sub2){
      $subpath=$subpath."/".$sub2;
    }

    my @iteminfo=OpenDIA::Collections::analyze_item($collection,$item.$subpath);
    my $metainfo=OpenDIA::Collections::analyze_meta($collection,$item,$subpath,$image);
        

    my $ttdata={
		collection   => $collection,
		item       => $item,
		sub        => $sub,
		sub1       => $sub1,
		sub2       => $sub2,
		image      => $image,
		meta       => $meta,
		iteminfo     => \@iteminfo,
		metainfo     => $metainfo,
		config       => \%config,
	       };
    
    # Dann Ausgabe des neuen Headers
    
    print $r->send_http_header("text/html");
    
    $template->process($config{tt_editor_editmeta_tname}, $ttdata) || do { 
      $r->log_reason($template->error(), $r->filename);
      return SERVER_ERROR;
    };
    
    return OK;

  }
  elsif ($action eq "savemeta"){

    my $subpath=$config{collection_base_dir}."/$collection";
    
    if ($item){
      $subpath=$subpath."/".$item;
    }
    if ($sub){
      $subpath=$subpath."/".$sub;
    }
    if ($sub1){
      $subpath=$subpath."/".$sub1;
    }
    if ($sub2){
      $subpath=$subpath."/".$sub2;
    }

    $image="meta" unless ($image);

    $subpath=$subpath."/".$image;

    foreach my $metaschemeref (@{$config{"metascheme"}{"$collection"}{"$meta"}}){
      my %metascheme=%$metaschemeref;

      if ($query->param($metascheme{"cat"})){
	open(META,">$subpath"."_".$metascheme{"cat"}.".dsc");
	print META $query->param($metascheme{"cat"});
	close(META);
      }
    }

    if ($item){
      $r->internal_redirect("http://$config{servername}$config{editor_loc}?action=showitem;collection=$collection;item=$item");
    }
    else {
      $r->internal_redirect("http://$config{servername}$config{editor_loc}?action=choosecollection;collection=$collection");
    }

    return OK;

  }
  elsif ($action eq "importpool"){

    # Bestehende Katalogaufnahmen dienen immer nur als Beschreibung
    # fuer das gesamte Digitalisat

    my $subpath=$config{collection_base_dir}."/$collection/$item/meta";

    # Satz holen

    my $soap = SOAP::Lite
      -> uri("urn:/Media")
	-> proxy($config{importpool}{$collection}{wsurl});
    my $result = $soap->get_native_title_by_katkey($config{importpool}{$collection}{dbname},$item);
    
    unless ($result->fault || !$result->result ) {
      my %title = %{$result->result};
      
      my %metainfos=();
      
      foreach my $key (sort keys %title){
	my $basecat=substr($key,0,4);
	my $convcat=$config{importpool}{$collection}{mapping}{"$basecat"};
	if ($convcat){
	  if (!$metainfos{$convcat}){
	    $metainfos{$convcat}=$title{$key};
	  }
	  else {
	    $metainfos{$convcat}=$metainfos{$convcat}.". - ".$title{$key};
	  }
	}
      }
      
      foreach my $metaschemeref (@{$config{"metascheme"}{"$collection"}{"$meta"}}
				){
	my %metascheme=%$metaschemeref;
	
	if ($metainfos{$metascheme{"cat"}}){
	  open(META,">$subpath"."_".$metascheme{"cat"}.".dsc");
	  print META $metainfos{$metascheme{"cat"}};
	  close(META);
	}
      }
      
    }
    else {
      $logger->error("SOAP MediaStatus Error", join ', ', $result->faultcode,
		     $result->faultstring, $result->faultdetail);
    }

    $r->internal_redirect("http://$config{servername}$config{editor_loc}?action=editmeta;collection=$collection;item=$item;sub=$sub;sub1=$sub1;sub2=$sub2;image=$image;meta=$meta");

    return OK;
    
  }
  else {
    # TT-Data erzeugen
    
    my $ttdata={
		errmsg       => "Unerlaubte Aktion",
		config       => \%config,
	       };
    
    # Dann Ausgabe des neuen Headers
    
    print $r->send_http_header("text/html");
    
    $template->process($config{tt_error_tname}, $ttdata) || do { 
      $r->log_reason($template->error(), $r->filename);
      return SERVER_ERROR;
    };
    
    return OK;
  }

}

1;
