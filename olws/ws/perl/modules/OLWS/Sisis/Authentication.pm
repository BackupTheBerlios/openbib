#####################################################################
#
#  Open Library WebServices
#
#  OLWS::Sisis::Authentication
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

package OLWS::Sisis::Authentication;

use strict;
use warnings;

use Log::Log4perl qw(get_logger :levels);

use DBI;

use OLWS::Sisis::Config;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace

use vars qw(%config);

*config=\%OLWS::Sisis::Config::config;

sub authenticate_user {
  
  my ($class, $username, $password, $database) = @_;
  
  # Log4perl logger erzeugen
  
  my $logger = get_logger();

  #####################################################################
  # Verbindung zur SQL-Datenbank herstellen
  
  my $dbh=DBI->connect("DBI:$config{dbimodule}:dbname=$database;host=$config{dbhost};port=$config{dbport}", $config{dbuser}, $config{dbpasswd})  or $logger->error_die($DBI::errstr);

  my $result=$dbh->prepare("select * from d02ben where d02bnr = ? and d02opacpin = ?") or $logger->error($DBI::errstr);
  $result->execute($username,$password) or $logger->error($DBI::errstr);
  
  my $rows=$result->rows();

  if ($rows <= 0){
    $result->finish;
    $dbh->disconnect();
    return undef;
  }

  my $res=$result->fetchrow_hashref();
  
  # Personendaten
  my $vorname=$res->{'d02vname'};
  my $nachname=$res->{'d02name'};
  my $geschlecht=$res->{'d02sex'};
  my $geburtsdatum=$res->{'d02gedatum'};
  my $ort=$res->{'d02o1'};
  my $strasse=$res->{'d02s1'};
  my $plz=$res->{'d02p1'};

  my $sperre=$res->{'d02sp1'};

  # Gebuehrendaten
  my $soll=$res->{'d02so1'};
  my $guthaben=$res->{'d02gut'};

  # Ausleihdaten
  my $avanz=$res->{'d02avanz'};           # Anzahl ausgeliehender Medien
  my $bsanz=$res->{'d02bsanz'};           # Anzahl ausgeliehender Medien
  my $bestellanz=$res->{'d02bestellanz'}; # Anzahl bestellter Medien
  my $pflanz=$res->{'d02pflanz'};         # Anzahl fernleihbestellter Medien
  my $vmanz=$res->{'d02vmanz'};           # Anzahl vorgemerkter Medien
  my $maanz=$res->{'d02maanz'};           # Anzahl gemahnter Medien
  my $vlanz=$res->{'d02vlanz'};           # Anzahl verlaengerter Medien

  my $userinfo={
		Vorname => $vorname,
		Nachname => $nachname,
		Geschlecht => $geschlecht,
		Geburtsdatum => $geburtsdatum,
		Ort =>$ort,
		Strasse => $strasse,
		PLZ => $plz,

		Sperre => $sperre,

		Soll => $soll,
		Guthaben => $guthaben,

		Avanz => $avanz,
		Bsanz => $bsanz,
		Bestellanz => $bestellanz,
		Pflanz => $pflanz,
		Vmanz => $vmanz,
		Maanz => $maanz,
		Vlanz => $vlanz,		
	       };

  $result->finish;
  $dbh->disconnect();

  return $userinfo;
}

1;
