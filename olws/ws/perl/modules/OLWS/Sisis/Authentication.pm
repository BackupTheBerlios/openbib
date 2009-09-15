#####################################################################
#
#  Open Library WebServices
#
#  OLWS::Sisis::Authentication
#
#  Dieses File ist (C) 2005-2007 Oliver Flimm <flimm@openbib.org>
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
use Data::Dumper;
use Encode qw/encode decode/;
use DBI;
use YAML;

use OLWS::Common::Utils;
use OLWS::Sisis::Config;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace

use vars qw(%config);

*config=\%OLWS::Sisis::Config::config;

sub authenticate_user {
  my ($class, $args_ref) = @_;

  my $username = $args_ref->{username};
  my $password = $args_ref->{password};
  my $database = $args_ref->{database};

  # Log4perl logger erzeugen

  my $logger = get_logger();

  $logger->info("$username - $password - $database");
  $logger->info(Dumper($args_ref));
  
  #####################################################################
  # Verbindung zur SQL-Datenbank herstellen
  
  my $dbh=DBI->connect("DBI:$config{dbimodule}:dbname=$database;server=$config{dbserver};host=$config{dbhost};port=$config{dbport}", $config{dbuser}, $config{dbpasswd}) or $logger->error_die($DBI::errstr);

  my $sql_statement = qq{
  select count(*) 

  from $database.sisis.d02ben 

  where d02bnr = ? 
    and d02opacpin = ?
  };
  
  my $request=$dbh->prepare($sql_statement);
  
  $request->execute($username,$password) or $logger->error_die($DBI::errstr);
  
  my @resarr=$request->fetchrow_arrayref();
  my $count=$resarr[0][0];
  
      $logger->info("Count:$count");

  if ($count != 1){
      $logger->info("Wrong Count:$count");
    $request->finish;
    $dbh->disconnect();
    return undef;
  }
  
  $sql_statement = qq{
  select * 

  from $database.sisis.d02ben 

  where d02bnr = ? 
    and d02opacpin = ?
  };

  $request=$dbh->prepare($sql_statement);
  
  $request->execute($username,$password) or $logger->error_die($DBI::errstr);
  
  my $res=$request->fetchrow_hashref();
  
  # Personendaten
  my $vorname      = ($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$res->{'d02vname'})):decode("iso-8859-1",$res->{'d02vname'});
  my $nachname     = ($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$res->{'d02name'})):decode("iso-8859-1",$res->{'d02name'});
  my $geschlecht   = ($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$res->{'d02sex'})):decode("iso-8859-1",$res->{'d02sex'});
  my $geburtsdatum = OLWS::Common::Utils::conv_date($res->{'d02gedatum'});
  my $ort          = ($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$res->{'d02o1'})):decode("iso-8859-1",$res->{'d02o1'});
#  my $strasse      = decode("iso-8859-1",$res->{'d02s1'});
  my $strasse      = ($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$res->{'d02s1'})):decode("iso-8859-1",$res->{'d02s1'});
  my $plz          = $res->{'d02p1'};
  
  # Gebuehrendaten
  my $soll         = $res->{'d02so1'};
  my $guthaben     = $res->{'d02gut'};

  # Ausleihdaten
  my $avanz        = $res->{'d02avanz'};           # Anzahl ausgeliehender Medien
  my $branz        = $res->{'d02branz'};           # Anzahl rueckgeforderter Medien
  my $bestellanz   = $res->{'d02bestellanz'};      # Anzahl bestellter Medien
  my $pflanz       = $res->{'d02pflanz'};          # Anzahl fernleihbestellter Medien
  my $vmanz        = $res->{'d02vmanz'};           # Anzahl vorgemerkter Medien
  #my $maanz        = $res->{'d02maanz'};          # Anzahl gemahnter Medien
  my $vlanz        = $res->{'d02vlanz'};           # Anzahl verlaengerter Medien
  my $sperre       = $res->{'d02sp1'};             # Sperre (inkl. Grund)
  my $sperrdatum   = OLWS::Common::Utils::conv_date($res->{'d02d1sperre'}); # Sperrdatum

  $sql_statement = qq{
  select * 

  from $database.sisis.d02onl 

  where d02obnr = ? 
    and d02oart = 1
  };

  $request=$dbh->prepare($sql_statement);
  
  $request->execute($username) or $logger->error_die($DBI::errstr);
  
  my @emailadr=();
  while (my $res=$request->fetchrow_hashref()){
    my $singleemail=($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$res->{'d02ozeile'})):decode("iso-8859-1",$res->{'d02ozeile'});
    push @emailadr, $singleemail;
  }	
  
  my $email=join(" ; ",@emailadr);
  
  $sql_statement = qq{
  select count(*) 

  from $database.sisis.d01buch 

  where d01bnr = ? 
    and d01status = 2
  };

  $request=$dbh->prepare($sql_statement) or $logger->error_die($DBI::errstr);
  
  $request->execute($username) or $logger->error_die($DBI::errstr);
  
  my @resarray=$request->fetchrow_array();
  my $bsanz=$resarray[0];
  
  # Sperre
  if ($sperre){
    my $request=$dbh->prepare("select d65text from $database.sisis.d65param where d65nr = ? and d65typ=2") or $logger->error_die($DBI::errstr);
    $request->execute($sperre) or $logger->error_die($DBI::errstr);
    
    while (my $res=$request->fetchrow_hashref()){
      my $sperrgrund=($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$res->{'d65text'})):decode("iso-8859-1",$res->{'d65text'});
      $sperre=$sperrgrund;
    }	
    $request->finish;
  }

  $sql_statement = qq{
  select count(*) 

  from $database.sisis.d03geb 

  where d03bnr = ? 
    and d03stat != 4128
  };

  $request=$dbh->prepare($sql_statement) or $logger->error_die($DBI::errstr);
  
  $request->execute($username) or $logger->error_die($DBI::errstr);
  
  @resarr=$request->fetchrow_arrayref();
  my $maanz=$resarr[0][0];

  my $userinfo_ref = SOAP::Data->name(User  => \SOAP::Data->value(
		SOAP::Data->name(Vorname      => $vorname)->type('string'),
		SOAP::Data->name(Nachname     => $nachname)->type('string'),
		SOAP::Data->name(Geschlecht   => $geschlecht)->type('string'),
		SOAP::Data->name(Geburtsdatum => $geburtsdatum)->type('string'),
		SOAP::Data->name(Ort          => $ort)->type('string'),
		SOAP::Data->name(Strasse      => $strasse)->type('string'),
		SOAP::Data->name(PLZ          => $plz)->type('string'),

		SOAP::Data->name(Soll         => $soll)->type('float'),
		SOAP::Data->name(Guthaben     => $guthaben)->type('float'),

		SOAP::Data->name(Avanz        => $avanz)->type('int'),
		SOAP::Data->name(Branz        => $branz)->type('int'),
		SOAP::Data->name(Bsanz        => $bsanz)->type('int'),
		SOAP::Data->name(Bestellanz   => $bestellanz)->type('int'),
		SOAP::Data->name(Pflanz       => $pflanz)->type('int'),
		SOAP::Data->name(Vmanz        => $vmanz)->type('int'),
		SOAP::Data->name(Maanz        => $maanz)->type('int'),
		SOAP::Data->name(Vlanz        => $vlanz)->type('int'),

                SOAP::Data->name(Sperre       => $sperre)->type('string'),		
                SOAP::Data->name(Sperrdatum   => $sperrdatum)->type('string'),
                SOAP::Data->name(Email        => $email)->type('string')
  ));

  $logger->info(Dumper($userinfo_ref));
  $request->finish;
  $dbh->disconnect();

  return $userinfo_ref;
}

1;
