#####################################################################
#
#  Open Library WebServices
#
#  OLWS::Sisis::MediaStatus
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

package OLWS::Sisis::MediaStatus;

use strict;
use warnings;

use DBI;

use OLWS::Sisis::Config;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace

use vars qw(%config);

*config=\%OLWS::Sisis::Config::config;

sub get_mediastatus {
  
  my ($class, $katkey, $database) = @_;
  
  #####################################################################
  # Verbindung zur SQL-Datenbank herstellen
  
  my $dbh=DBI->connect("DBI:$config{dbimodule}:dbname=$database;server=$config{dbserver};host=$config{dbhost};port=$config{dbport}", $config{dbuser}, $config{dbpasswd});
  
  my $result=$dbh->prepare("select * from $database.sisis.d50zweig");
  $result->execute();
  
  my %zweig=();
  while (my $res=$result->fetchrow_hashref()){
    $zweig{$res->{'d50zweig'}}{Bezeichnung}=$res->{'d50bezeich'};
  }
  
  $result=$dbh->prepare("select * from $database.sisis.d60abteil");
  $result->execute();
  
  my %abteilung=();
  while (my $res=$result->fetchrow_hashref()){
    $abteilung{$res->{'d60zweig'}}{$res->{'d60abt'}}=$res->{'d60bezeich'};
  }
  
  $result=$dbh->prepare("select d01ort,d01entl,d01mtyp,d01ex,d01status,d01rv,d01abtlg,d01zweig from $database.sisis.d01buch where d01katkey = ?");
  $result->execute($katkey);
  
  my @exemplarliste=();
  while (my $res=$result->fetchrow_hashref()){
    my $signatur=$res->{'d01ort'};
    my $exemplar=$res->{'d01ex'};
    my $rueckgabe=$res->{'d01rv'};
    my $entl=$res->{'d01entl'};
    my $status=$res->{'d01status'};
    my $standort=$res->{'d01abtlg'};
    my $mtyp=$res->{'d01mtyp'};
    my $zweignr=$res->{'d01zweig'};
    my $zweigst="";
    
    if ($abteilung{"$zweignr"}{"$standort"}){
      $standort=$abteilung{"$zweignr"}{"$standort"};
    }
    
    if ($zweig{"$zweignr"}{Bezeichnung}){
      $standort=$zweig{"$zweignr"}{Bezeichnung}." / $standort";
    }
    
    if ($status eq "0"){
      $status="bestellbar";
    }
    elsif ($status eq "2"){
      $status="bestellt";
    }
    elsif ($status eq "4"){
      $status="entliehen";
    }
    else {
      $status="unbekannt";
    }
    
    if ($signatur=~/^19A/ || $signatur=~/^2\dA/ || $signatur=~/3[0-3]A/){
      if ($status eq "bestellbar"){
	$status="<a href=\"http://www.ub.uni-koeln.de/ub/Abteilungen/ortsleih/infoblat/sab.html\" target=\"_blank\">SAB</a> / ausleihbar";
      }
      else {
	$status="<a href=\"http://www.ub.uni-koeln.de/ub/Abteilungen/ortsleih/infoblat/sab.html\" target=\"_blank\">SAB</a> / vormerkbar";
      }
    }
    
    $rueckgabe=~s/12:00AM//;
    
    $standort="-" unless ($standort);
    
    my $singleex={
		  Signatur => $signatur,
		  Exemplar => $exemplar,
		  Standort => $standort,
		  Status => $status,	
		  Rueckgabe => $rueckgabe,
		 };
    
    push @exemplarliste, $singleex;
  }
  
  return \@exemplarliste;
}

1;
