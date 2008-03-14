#!/usr/bin/perl

#####################################################################
#
#  collector.pl
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

use strict;
use warnings;
no warnings 'redefine';

use Log::Log4perl qw(get_logger :levels);

use DBI;

use File::Find::Rule;

use OpenDIA::Config;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace

use vars qw(%config);

*config=\%OpenDIA::Config::config;

Log::Log4perl->init_once($config{log4perl_path});

my $logger = get_logger();

my $collectionbasedir=$config{collection_base_dir};

# Verbindung zur SQL-Datenbank herstellen

my $metadbh=DBI->connect("DBI:$config{dbimodule}:dbname=$config{metadbname};host=$config{metadbhost};port=$config{metadbport}", $config{metadbuser}, $config{metadbpasswd}) or $logger->error_die($DBI::errstr);

my $request=$metadbh->do("truncate table meta");

my $rule=File::Find::Rule->new;

my @files = File::Find::Rule->relative->file()->in( $collectionbasedir );

foreach my $file (@files){
  print ".";

  my ($metapath,$metaelement,$category,$ext)=("","","","");

  if ($file=~/.*\.dsc$/){
    # Metadaten
    ($metapath,$metaelement,$category)=$file=~m/^(.*)\/(.+?)_(.+?)\.dsc$/;
  }
  elsif ($file=~/\.tif$/ || $file =~/\.jpg$/ || $file =~/\.png$/) {
    # Originaldaten
    ($metapath,$metaelement)=$file=~m/^(.*)\/(.+?\....)$/;
  }

  my @path=split("\/",$metapath);

  my $collection="";
  my $item="";
  my $sub="";
  my $sub1="";
  my $sub2="";

  my $image="";

  my $type="";
  my $metascheme="";

  if (defined($path[0])){
    $collection=$path[0];
  }

  if (defined($path[1])){
    $item=$path[1];
  }

  if (defined($path[2])){
    $sub=$path[2];
  }

  if (defined($path[3])){
    $sub1=$path[3];
  }

  if (defined($path[4])){
    $sub2=$path[4];
  }

  if ($metaelement eq "meta"){
    $type="orgunit";
    $image="";
  }
  else {
    $type="image";
    $image=$metaelement;
  };

  if ($category=~m/^DC/){
    $metascheme="dc";
  }
  elsif ($category=~m/^M\d/){
    $metascheme="emab";
  }
  
#  print "PATH: $metapath - CAT: $category - C: $collection I: $item S0: $sub S1: $sub1 S2: $sub2 EL: $metaelement - ALL: $file SCH: $metascheme TY: $type\n";

#  next;

  my $content="";
  open (META,"$collectionbasedir/$file");
  while (<META>){
    $content=$content.$_;
  }
  close (META);

  my @multcontent=split(". - ",$content);
  
  foreach my $singlecontent (@multcontent){
    $request=$metadbh->prepare("insert into meta values (NULL,?,?,?,?,?,?,?,?,?,?,?)");
    $request->execute($collection,$item,$sub,$sub1,$sub2,$image,$type,$metascheme,$category,$singlecontent,$singlecontent);
  }
}

print "\n";
$request->finish();
$metadbh->disconnect();
