#####################################################################
#
#  Open Library WebServices
#
#  OLWS::Sisis::Circulation
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

package OLWS::Sisis::Circulation;

use strict;
use warnings;

use DBI;

use OLWS::Sisis::Config;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace

use vars qw(%config);

*config=\%OLWS::Sisis::Config::config;

# Verlaengerungen

sub get_renewals {

  return;
}

# Vormerkungen

sub get_reservations {

  return;
}

# Mahnungen

sub get_reminders {

  return;
}

# Aktive Ausleihen

sub get_borrows {
  
  my ($class, $username, $password, $database) = @_;

  #####################################################################
  # Verbindung zur SQL-Datenbank herstellen
  
  my $dbh=DBI->connect("DBI:$config{dbimodule}:dbname=$database;server=$config{dbserver};host=$config{dbhost};port=$config{dbport}", $config{dbuser}, $config{dbpasswd});


  my $result=$dbh->prepare("select d01rv,d01katkey from $database.sisis.d01buch where d01bnr = ?");
  $result->execute($username);

  my %ausleihen=();
  while (my $res=$result->fetchrow_hashref()){
    $ausleihen{$res->{'d01katkey'}}=$res->{'d01rv'};
  }

  my @ausleihliste=();

  while (my ($katkey,$rueckgabe)= each %ausleihen){

    $result=$dbh->prepare("select autor_avs,titel_avs,erschjahr from $database.sisis.titel_dupdaten where katkey = ?");
    $result->execute($katkey);

    while (my $res=$result->fetchrow_hashref()){
      my $verfasser=$res->{autor_avs};
      my $titel=$res->{titel_avs};
      my $ejahr=$res->{erschjahr};
    
      my $singleausleihe={
	       Verfasser       => $verfasser,
	       Titel           => $titel,
               EJahr           => $ejahr,
	       RueckgabeDatum  => $rueckgabe,
		 };
    
      push @ausleihliste, $singleausleihe;
    }
  
  }

  return \@ausleihliste;
}

1;
