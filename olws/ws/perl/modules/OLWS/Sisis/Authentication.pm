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

use DBI;

use OLWS::Sisis::Config;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace

use vars qw(%config);

*config=\%OLWS::Sisis::Config::config;

sub authenticate_user {
  
  my ($class, $username, $password, $database) = @_;

  my %monthtab=(
             Jan => '01',
             Feb => '02',
             Mar => '03',
             Apr => '04',
             May => '05',
             Jun => '06',
             Jul => '07',
             Aug => '08',
             Sep => '09',
             Oct => '10',
             Nov => '11',
             Dec => '12',
            );
  
  #####################################################################
  # Verbindung zur SQL-Datenbank herstellen
  
  my $dbh=DBI->connect("DBI:$config{dbimodule}:dbname=$database;server=$config{dbserver};host=$config{dbhost};port=$config{dbport}", $config{dbuser}, $config{dbpasswd});

  my $result=$dbh->prepare("select count(*) from $database.sisis.d02ben where d02bnr = ? and d02opacpin = ?");

  $result->execute($username,$password);
  
  my @resarr=$result->fetchrow_arrayref();
  my $count=$resarr[0][0];

  if ($count != 1){
    $result->finish;
    $dbh->disconnect();
    return undef;
  }

  my $result=$dbh->prepare("select * from $database.sisis.d02ben where d02bnr = ? and d02opacpin = ?");

  $result->execute($username,$password);

  my $res=$result->fetchrow_hashref();
  
  # Personendaten
  my $vorname=$res->{'d02vname'};
  my $nachname=$res->{'d02name'};
  my $geschlecht=$res->{'d02sex'};
  my $geburtsdatum=$res->{'d02gedatum'};
  my $ort=$res->{'d02o1'};
  my $strasse=$res->{'d02s1'};
  my $plz=$res->{'d02p1'};

  # Gebuehrendaten
  my $soll=$res->{'d02so1'};
  my $guthaben=$res->{'d02gut'};

  # Ausleihdaten
  my $avanz=$res->{'d02avanz'};           # Anzahl ausgeliehender Medien
  my $branz=$res->{'d02branz'};           # Anzahl rueckgeforderter Medien
  my $bestellanz=$res->{'d02bestellanz'}; # Anzahl bestellter Medien
  my $pflanz=$res->{'d02pflanz'};         # Anzahl fernleihbestellter Medien
  my $vmanz=$res->{'d02vmanz'};           # Anzahl vorgemerkter Medien
  my $maanz=$res->{'d02maanz'};           # Anzahl gemahnter Medien
  my $vlanz=$res->{'d02vlanz'};           # Anzahl verlaengerter Medien
  my $sperre=$res->{'d02sp1'};            # Sperre (inkl. Grund)
  my $sperrdatum=$res->{'d02d1sperre'};        # Sperrdatum

  my ($month,$day,$year)=$geburtsdatum=~m/^([A-Za-z]+)\s+(\d+)\s+(\d+)\s+/;
  $day=~s/^(\d)$/0$1/;
  $month=~s/^(\d)$/0$1/;
  $geburtsdatum=$day.".".$monthtab{$month}.".".$year;

  ($month,$day,$year)=$sperrdatum=~m/^([A-Za-z]+)\s+(\d+)\s+(\d+)\s+/;
  $day=~s/^(\d)$/0$1/;
  $month=~s/^(\d)$/0$1/;
  $sperrdatum=$day.".".$monthtab{$month}.".".$year;


  $result=$dbh->prepare("select * from $database.sisis.d02onl where d02obnr = ? and d02oart = 1");

  $result->execute($username);

  my @emailadr=();
  while (my $res=$result->fetchrow_hashref()){
    my $singleemail=$res->{'d02ozeile'};
    push @emailadr, $singleemail;
  }	
  
  my $email=join(" ; ",@emailadr);

  my $userinfo={
		Vorname => $vorname,
		Nachname => $nachname,
		Geschlecht => $geschlecht,
		Geburtsdatum => $geburtsdatum,
		Ort =>$ort,
		Strasse => $strasse,
		PLZ => $plz,

		Soll => $soll,
		Guthaben => $guthaben,

		Avanz => $avanz,
		Branz => $branz,
		Bestellanz => $bestellanz,
		Pflanz => $pflanz,
		Vmanz => $vmanz,
		Maanz => $maanz,
		Vlanz => $vlanz,

                Sperre => $sperre,		
                Sperrdatum => $sperrdatum,
                Email => $email,		
	       };

  $result->finish;
  $dbh->disconnect();

  return $userinfo;
}

1;
