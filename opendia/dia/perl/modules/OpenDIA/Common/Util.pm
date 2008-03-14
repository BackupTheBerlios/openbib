#####################################################################
#
#  OpenDIA::Common::Util
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

package OpenDIA::Common::Util;

use strict;
use warnings;
no warnings 'redefine';

use Apache::Constants qw(:common);
use Image::Magick;
use Image::Size;
use Log::Log4perl qw(get_logger :levels);
use SOAP::Lite;
use Template;
use YAML;

use OpenDIA::Collections;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace
use vars qw(%config);

*config=\%OpenDIA::Config::config;

sub print_page {
  my ($templatename,$ttdata,$r)=@_;

  # Log4perl logger erzeugen
  my $logger = get_logger();
  
  my $stylesheet=get_css_by_browsertype($r);

  my $query=Apache::Request->new($r);

  my $view       = ($query->param('view'))?$query->param('view'):undef;
  my $collection = ($query->param('collection'))?$query->param('collection'):undef;

  if ($view && -e "$config{tt_include_path}/views/$view/$templatename"){
    $templatename="views/$view/$templatename";
  }

  # Database-Template ist spezifischer als View-Template und geht vor
  if ($collection && -e "$config{tt_include_path}/collection/$collection/$templatename"){
    $templatename="collecction/$collection/$templatename";
  }
  
  my $template = Template->new({ 
				ABSOLUTE      => 1,
				INCLUDE_PATH  => $config{tt_include_path},
				OUTPUT        => $r,     # Output geht direkt an Apache Request
			       });
  
  # Dann Ausgabe des neuen Headers
  print $r->send_http_header("text/html");
  
  $template->process($templatename, $ttdata) || do { 
    $r->log_reason($template->error(), $r->filename);
    return SERVER_ERROR;
  };
  
  return;
}   

sub get_css_by_browsertype {
  my ($r)=@_;

  # Log4perl logger erzeugen
  my $logger = get_logger();

  my $useragent=$r->subprocess_env('HTTP_USER_AGENT');

  my $query=Apache::Request->new($r);
  my $view=($query->param('view'))?$query->param('view'):undef;

  my $stylesheet="";
  if ( $useragent=~/Mozilla.5.0/ || $useragent=~/MSIE 5/ || $useragent=~/MSIE 6/ || $useragent=~/Konqueror"/ ){
    if ($useragent=~/MSIE/){
      $stylesheet="openbib-ie.css";
    }
    else {
      $stylesheet="openbib.css";
    }
  }
  else {
    if ($useragent=~/MSIE/){
      $stylesheet="openbib-simple-ie.css";
    }
    else {
      $stylesheet="openbib-simple.css";
    }
  }

  return $stylesheet;
}

sub getMetaFromDB {
  my ($metadbh,$collection,$item)=@_;

  # Log4perl logger erzeugen
  my $logger = get_logger();

  my %iteminfo=();

  $iteminfo{item}=$item;
  
  my $itembasedir=$config{collection_base_dir}."/$collection/$item";
  
  my $request=$metadbh->prepare("select distinct image from meta where collection=? and item=? and image != '' order by image");
  $request->execute($collection,$item);
  
  while (my $result=$request->fetchrow_hashref()){
    my %singleinfo=();
    $singleinfo{type}="image";
    $singleinfo{name}=$result->{image};

    my ($width, $height) = (-1,-1);

    ($width, $height) = imgsize("$itembasedir/".$singleinfo{name});

    $singleinfo{res}=$height."x".$width;

    my ($imgsize)=(stat("$itembasedir/".$singleinfo{name}))[7];
    
    $singleinfo{size}=$imgsize;

    my ($front,$ext)=$singleinfo{name}=~m/^(.+?)\.(...)$/;
    
    my $thumb="";
    my $web="";
    
    if ( -e "$itembasedir/$front"."_thumb.jpg" ){
      $singleinfo{thumb}="$front"."_thumb.jpg";
    }
    
    if ( -e "$itembasedir/$front"."_web.jpg" ){
      $singleinfo{web}="$front"."_web.jpg";
    }
    
    my $request2=$metadbh->prepare("select category,content from meta where collection=? and item=? and sub='' and image=?");
    $request2->execute($collection,$item,$result->{image});
    
    while (my $result2=$request2->fetchrow_hashref()){
      $singleinfo{meta}{$result2->{category}}=$result2->{content};
    }
    
    push @{$iteminfo{images}}, \%singleinfo;
  }
  
  
  # Allgemeine Meta-Informationen zum Item holen
  my $request2=$metadbh->prepare("select category,content from meta where collection=? and item=? and sub='' and type='orgunit'");
  $request2->execute($collection,$item);
  
  while (my $result2=$request2->fetchrow_hashref()){
    my $category=$result2->{category};
    my $content=$result2->{content};
    
    push @{$iteminfo{meta}}, { category => $category,
                               content  => $content,
                               webarg   => convweb($content),
                           };
  }
  
  return \%iteminfo;
}

sub cleancontent {
  my ($content)=@_;

  $content=~s/< \/p>/<p>/g;

  return $content;
}

sub convweb {
  my ($content)=@_;

  $content=~s/&/\%26/g;
  $content=~s/#/\%23/g;
  $content=~s/< \/p>/<p>/g;

  return $content;
}	

sub genThumbFromFS {
  my ($collection,$item)=@_;

  # Log4perl logger erzeugen
  my $logger = get_logger();

  my $itembasedir=$config{collection_base_dir}."/$collection/$item";

  my @iteminfo=OpenDIA::Collections::analyze_item($collection,$item);

  unlink "$itembasedir/*_thumb.jpg";

  foreach my $img (@iteminfo){
    my ($front,$ext)=$img->{name}=~m/^(.+?)\.(...)$/;

#      unlink "$itembasedir/".$img->{thumb}  if ($img->{thumb});
#      next if ($img->{thumb});

    my $image=new Image::Magick;
    $image->Read("$itembasedir/".$img->{name});
    $image->Resize(geometry => '100x100>');
    $image->Write("jpg:$itembasedir/$front"."_thumb.jpg");
  }

  OpenDIA::Collections::update_item($collection,$item);

  return;
}

sub genWebFromFS {
  my ($collection,$item)=@_;

  # Log4perl logger erzeugen
  my $logger = get_logger();

  my $itembasedir=$config{collection_base_dir}."/$collection/$item";

  my @iteminfo=OpenDIA::Collections::analyze_item($collection,$item);

  unlink "$itembasedir/*_web.jpg";

  foreach my $img (@iteminfo){
    my ($front,$ext)=$img->{name}=~m/^(.+?)\.(...)$/;

#      unlink "$itembasedir/".$img->{web}  if ($img->{web});
#      next if ($img->{web});

    my $image=new Image::Magick;
    $image->Read("$itembasedir/".$img->{name});
    $image->Resize(geometry => '1024x1024>');
    $image->Write("jpg:$itembasedir/$front"."_web.jpg");
  }

  OpenDIA::Collections::update_item($collection,$item);

  return;
}

sub importPoolData {
  my ($collection,$item,$meta)=@_;

  # Log4perl logger erzeugen
  my $logger = get_logger();
  
  # Bestehende Katalogaufnahmen dienen immer nur als Beschreibung
  # fuer das gesamte Digitalisat
  my $subpath=$config{collection_base_dir}."/$collection/$item/meta";

  unlink "$subpath/meta*.dsc";
  
  # Satz holen
  my $soap = SOAP::Lite
    -> uri("urn:/Media")
      -> proxy($config{importpool}{$collection}{wsurl});
  my $result = $soap->get_native_title_by_katkey(
                SOAP::Data->name(paramaters  =>\SOAP::Data->value(
                    SOAP::Data->name(katkey => $item)->type('int'),
                    SOAP::Data->name(database => $config{importpool}{$collection}{dbname})->type('string'))));

  $logger->info("SOAP-Status: ".YAML::Dump($result->fault));
  
  unless ($result->fault || !$result->result ) {
    my %title = %{$result->result};

    $logger->info("SOAP-Result: ".YAML::Dump(\%title));
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
    
    foreach my $metaschemeref (@{$config{"metascheme"}{"$collection"}{"$meta"}}){
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

  OpenDIA::Collections::update_item($collection,$item);

  return;
}

sub normalize {
  my ($line)=@_;

  $line=~s/Ä/Ae/g;
  $line=~s/ä/ae/g;
  $line=~s/Ö/Oe/g;
  $line=~s/ö/oe/g;
  $line=~s/Ü/Ue/g;
  $line=~s/ü/ue/g;
  $line=~s/É/E/g;
  $line=~s/é/e/g;
  $line=~s/ß/ss/g;

#  $line=~s/(.)/lc($1)/g;

  return ($line);
}

sub category_is_numeric {
    my ($collection,$format,$category)=@_;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $categories=$config{metascheme}{$collection}{$format};

    foreach my $cat (@{$categories}){
        $logger->info("$collection $format $category Numeric $cat->{numeric}");
            

        if ($cat->{cat} eq $category && exists $cat->{numeric}){
            return 1;
        }
        
    }
    return 0;
}   

1;
