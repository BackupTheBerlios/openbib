#####################################################################
#
#  Open Library WebServices
#
#  OLWS::MediaStatus
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

use Log::Log4perl qw(get_logger :levels);

use DBI;

use OLWS::Sisis::Config;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace

use vars qw(%config);

*config=\%OLWS::Sisis::Config::config;

sub get_mediastatus {
  
  my ($class, $katkey, $database) = @_;
  
  # Log4perl logger erzeugen
  
  my $logger = get_logger();
  
  #####################################################################
  # Verbindung zur SQL-Datenbank herstellen
  
  my $dbh=DBI->connect("DBI:$config{dbimodule}:dbname=$database;host=$config{dbhost};port=$config{dbport}", $config{dbuser}, $config{dbpasswd}) or $logger->error_die($DBI::errstr);

  my $result=$dbh->prepare("select d01buch.d01ort,d01buch.d01ex,d01buch.d01status,d01buch.d01rv from d01buch where d01buch.d01katkey = ?") or $logger->error($DBI::errstr);
  $result->execute($katkey) or $logger->error($DBI::errstr);
  
  my @exemplarliste=();
  while (my $res=$result->fetchrow_hashref()){
    my $signatur=$res->{'d01ort'};
    my $exemplar=$res->{'d01ex'};
    my $rueckgabe=$res->{'d01rv'};
    my $status=$res->{'d01status'};
    my $standort=$res->{'d60bezeich'};

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
      # $status="Pr&auml;senzbestand";
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
