#!/usr/bin/perl

use Getopt::Long;
use Log::Log4perl;

use OpenDIA::Collections;
use OpenDIA::Common::Util;
use OpenDIA::Config;

# Definition der Programm-Optionen
my ($collection,$singleitem,$import,$genthumb,$genweb);

&GetOptions("collection=s" => \$collection,
            "singleitem=s" => \$singleitem,
	    "import"       => \$import,
	    "genthumb"     => \$genthumb,
	    "genweb"       => \$genweb,
           );


my %valid_collections=(
		       'einbaende' => 1,
		       'portrait' => 1,
		       'landschaft' => 1,
		      );

my %meta=(
	  'einbaende' => 'emab',
	  'portrait'  => 'emab',
	  'landschaft'  => 'pmab',
	 );

unless ($valid_collections{$collection} == 1){
  print STDERR "Sammlung $collection NICHT gueltig\n";
  exit;
}	

Log::Log4perl->init_once($OpenDIA::Config::config{log4perl_path});

my @itemlist=();

if ($singleitem){
  push @itemlist, $singleitem;
}
else {
  @itemlist=OpenDIA::Collections::get_items("$collection");
}

if (!$import && !$genthumb && !$genweb){
  $import=1;
  $genthumb=1;
  $genweb=1;
}

foreach my $item (@itemlist){
 
  print STDERR "Bearbeitung von Digitalisat $item beginnt\n";

  if ($genthumb){
    print STDERR "Aufbau der Thumbnails\n";

    OpenDIA::Common::Util::genThumbFromFS($collection,$item);
  }

  if ($genweb){
    print STDERR "Aufbau der Web-Bilder\n";

    OpenDIA::Common::Util::genWebFromFS($collection,$item);
  }

  if ($import){
    print STDERR "Import der Katalog-Daten\n";

    OpenDIA::Common::Util::importPoolData($collection,$item,$meta{$collection});
  }

  print STDERR "Bearbeitung von Digitalisat $item beendet\n\n";
  
}
