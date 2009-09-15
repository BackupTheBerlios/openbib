#####################################################################
#
#  Open Library WebServices
#
#  OLWS::Sisis::Circulation
#
#  Dieses File ist (C) 2005-2009 Oliver Flimm <flimm@openbib.org>
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

use Log::Log4perl qw(get_logger :levels);
use Encode qw/encode decode/;

use DBI;

use OLWS::Sisis::Data;
use OLWS::Sisis::Config;
use OLWS::Common::SLNP::Circulation;
use OLWS::Common::Utils;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace

use vars qw(%config);

*config=\%OLWS::Sisis::Config::config;

sub new {
    my ($class,$database) = @_;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $config = new OLWS::Sisis::Config();
    
    my $self = { };

    bless ($self, $class);

    # Verbindung zur SQL-Datenbank herstellen
    my $dbh
        = DBI->connect("DBI:$config->{dbimodule}:dbname=$database;server=$config->{dbserver};host=$config->{dbhost};port=$config->{dbport}", $config->{dbuser}, $config->{dbpasswd})
            or $logger->error($DBI::errstr);

    $self->{dbh}       = $dbh;

    $self->{sikfstab}  = OLWS::Sisis::Data::get_sikfstabref($dbh,$database);

    return $self;
}

# Verlaengerungen

sub get_renewals {

  return;
}

# Bestellungen

sub get_orders {
  my ($self, $args_ref) = @_;

  my $username = $args_ref->{username};
  my $password = $args_ref->{password};
  my $database = $args_ref->{database};
  
  # Log4perl logger erzeugen
  
  my $logger = get_logger();

  my $sql_statement = qq{
  select d01gsi,d01ort,d01ex,d01av,d01rv,d01aufnahme,d01katkey,d01mtyp,d01skond 
  from $database.sisis.d01buch 

  where d01bnr = ? 
    and d01status = 2 

  order by d01rv asc
  };
  
  my $request=$self->{dbh}->prepare($sql_statement);
  
  $request->execute($username) or $logger->error_die($DBI::errstr);
  
  my $skond_map_ref = {
    0     => 'bestellt',                # kein Sonderstatus
    1     => 'Vormerkung priv. Gruppe',
    2     => 'Besondere Leihfrist',
    4     => 'Ausleihe mit Medienparameter',
    16    => 'verlustgebucht',
    64    => 'abholbar',
    128   => 'PFL auf R&uuml;ckversand',
    256   => 'Geb&uuml;hren u. Mahnungen vorhanden',
    512   => 'Mahnung ohne Geb&uuml;hr vorhanden',
    1024  => 'PFL wurde sondiert',
    2048  => 'r&uuml;ckgefordert wg. Benutzersperre',
    4096  => 'aktuelle Geb&uuml;hren vorhanden',
    8192  => 'bestellt', # Magazinbestellung
    16384 => 'offene OPAC PFL-Bestellung',
    32748 => 'abgesagte PFL-Bestellung',
  };  

  my @orderlist=();
  
  while (my $res=$request->fetchrow_hashref()){
    
    my $katkey          = $res->{'d01katkey'};
    my $mtyp            = $res->{'d01mtyp'};
    my $skond           = (exists $skond_map_ref->{$res->{'d01skond'}})?$skond_map_ref->{$res->{'d01skond'}}:'unbekannt';
    my $bestelldatumpfl = OLWS::Common::Utils::conv_date($res->{'d01aufnahme'});
    my $bestelldatum    = OLWS::Common::Utils::conv_date($res->{'d01av'});
    
    if ($mtyp eq "99"){
      $bestelldatum=$bestelldatumpfl;
    }

    my $signatur        = $res->{'d01ort'};
    
    if ($res->{'d01ex'}){
      $signatur=$signatur.$res->{'d01ex'};
    }

    $signatur           = ($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$signatur)):decode("iso-8859-1",$signatur);
    
    my $mediennummer    = ($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$res->{'d01gsi'})):decode("iso-8859-1",$res->{'d01gsi'});

    my $title_ref = get_short_title({
	katkey   => $katkey,
	mtyp     => $mtyp,
	dbh      => $self->{dbh},
	database => $database,
	sikfstab => $self->{sikfstab},
	});
    
    my $singleorder_ref = SOAP::Data->name(MediaItem  => \SOAP::Data->value(
		SOAP::Data->name(Katkey          => $katkey)->type('string'),
		SOAP::Data->name(Verfasser       => $title_ref->{Verfasser})->type('string'),
		SOAP::Data->name(Titel           => $title_ref->{Titel})->type('string'),
		SOAP::Data->name(EJahr           => $title_ref->{EJahr})->type('string'),
#		SOAP::Data->name(Signatur        => $signatur)->type('string'),
#		SOAP::Data->name(MTyp            => $mtyp)->type('string'),
		SOAP::Data->name(Mediennummer    => $mediennummer)->type('string'),
		SOAP::Data->name(BestellDatum    => $bestelldatum)->type('string'),
		SOAP::Data->name(Status          => $skond)->type('string'),
       ));
    
    push @orderlist, $singleorder_ref;    
  }

  return SOAP::Data->name(OrderList  => SOAP::Data->value(\@orderlist));
}


# Vormerkungen

sub get_reservations {
  my ($self, $args_ref) = @_;

  my $username = $args_ref->{username};
  my $password = $args_ref->{password};
  my $database = $args_ref->{database};

  # Log4perl logger erzeugen

  my $logger = get_logger();

#   my $sql_statement = qq{
#   select * 

#   from $database.sisis.d04vorm 

#   where d04bnr = ?
#   };

  my $sql_statement = qq{
  select d01ort, d04katkey, d04gsi, d04vmdatum, d04aufrecht, d04zweig 

  from $database.sisis.d04vorm, $database.sisis.d01buch

  where d01gsi=d04gsi
    and d04bnr = ?
  };
  
  my $request=$self->{dbh}->prepare($sql_statement);

  $sql_statement = qq{
  select * 
 
  from $database.sisis.d04vorm 

  where d04katkey = ? 

  order by d04vmnr
  };

  my $request2=$self->{dbh}->prepare($sql_statement);  

  my @reservationlist=();

  $request->execute($username) or $logger->error_die($DBI::errstr);
  
  while (my $res=$request->fetchrow_hashref()){
    
    my $katkey=$res->{'d04katkey'};

    my $title_ref = get_short_title({
	katkey   => $katkey,
	mtyp     => '',
	dbh      => $self->{dbh},
	database => $database,
	sikfstab => $self->{sikfstab},
	});
    
    my $stelle=-1;

    $request2->execute($katkey) or $logger->error_die($DBI::errstr);

    my $counter=1;

    while (my $res2=$request2->fetchrow_hashref()){

      my $bnr = $res2->{'d04bnr'};

      if ($bnr eq $username){
        $stelle=$counter;
        last;
      }

      $counter++;
    }

    my $vormerkdatum  = OLWS::Common::Utils::conv_date($res->{'d04vmdatum'});
    my $aufrechtdatum = OLWS::Common::Utils::conv_date($res->{'d04aufrecht'});
    my $mediennummer  = ($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$res->{'d04gsi'})):decode("iso-8859-1",$res->{'d04gsi'});
    my $signatur      = ($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$res->{'d01ort'})):decode("iso-8859-1",$res->{'d01ort'});
    my $zweigstelle   = ($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$res->{'d04zweig'})):decode("iso-8859-1",$res->{'d04zweig'});
    
    my $singlereservation_ref = SOAP::Data->name(MediaItem  => \SOAP::Data->value(
		SOAP::Data->name(Katkey          => $katkey)->type('string'),
		SOAP::Data->name(Verfasser       => $title_ref->{Verfasser})->type('string'),
		SOAP::Data->name(Titel           => $title_ref->{Titel})->type('string'),
		SOAP::Data->name(EJahr           => $title_ref->{EJahr})->type('string'),
		SOAP::Data->name(Signatur        => $signatur)->type('string'),
#		SOAP::Data->name(MTyp            => $mtyp)->type('string'),
		SOAP::Data->name(Mediennummer    => $mediennummer)->type('string'),
		SOAP::Data->name(VormerkDatum    => $vormerkdatum)->type('string'),
		SOAP::Data->name(AufrechtDatum   => $aufrechtdatum)->type('string'),
		SOAP::Data->name(Zweigstelle     => $zweigstelle)->type('string'),
		SOAP::Data->name(Stelle          => $stelle)->type('int'),	));
    
    push @reservationlist, $singlereservation_ref;    
  }

  $request->finish;
  $request2->finish;

  return SOAP::Data->name(ReservationList  => SOAP::Data->value(\@reservationlist));

}

# Mahnungen

sub get_reminders {
  my ($self, $args_ref) = @_;

  my $username = $args_ref->{username};
  my $password = $args_ref->{password};
  my $database = $args_ref->{database};

  # Log4perl logger erzeugen

  my $logger = get_logger();

  my $sql_statement = qq{
  select * 

  from $database.sisis.d03geb 

  where d03bnr = ? 
    and d03stat != 4128
  };
  
  my $request=$self->{dbh}->prepare($sql_statement);
  $request->execute($username) or $logger->error_die($DBI::errstr);
  
  my @reminderlist=();
  
  while (my $res=$request->fetchrow_hashref()){
    
    my $katkey          = $res->{'d03katkey'};
    
    my $saeumnisgebuehr = $res->{'d03gebu'};
    my $mahngebuehr     = $res->{'d03mahn'};
    my $mtyp            = $res->{'d03mtyp'};

    my $ausleihdatum    = OLWS::Common::Utils::conv_date($res->{'d03von'});
    my $leihfristende   = OLWS::Common::Utils::conv_date($res->{'d03lfe'});

    if ($mtyp == 99){
      $leihfristende="-";
    }

    my $mediennummer    = ($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$res->{'d03gsi'})):decode("iso-8859-1",$res->{'d03gsi'});

    my $title_ref = get_short_title({
	katkey   => $katkey,
	mtyp     => $mtyp,
	dbh      => $self->{dbh},
	database => $database,
	sikfstab => $self->{sikfstab},
	});

    my $singlereminder_ref = SOAP::Data->name(MediaItem  => \SOAP::Data->value(
		SOAP::Data->name(Katkey          => $katkey)->type('string'),
		SOAP::Data->name(Verfasser       => $title_ref->{Verfasser})->type('string'),
		SOAP::Data->name(Titel           => $title_ref->{Titel})->type('string'),
		SOAP::Data->name(EJahr           => $title_ref->{EJahr})->type('string'),
#		SOAP::Data->name(Signatur        => $signatur)->type('string'),
		SOAP::Data->name(MTyp            => $mtyp)->type('string'),
		SOAP::Data->name(Mediennummer    => $mediennummer)->type('string'),
		SOAP::Data->name(AusleihDatum    => $ausleihdatum)->type('string'),
		SOAP::Data->name(Leihfristende   => $leihfristende)->type('string'),
		SOAP::Data->name(Mahngebuehr     => $mahngebuehr)->type('string'),
		SOAP::Data->name(Saeumnisgebuehr => $saeumnisgebuehr)->type('string'),	));
    
    push @reminderlist, $singlereminder_ref;
  }

  $request->finish;

  return SOAP::Data->name(ReminderList  => SOAP::Data->value(\@reminderlist));  
}

# Aktive Ausleihen

sub get_borrows {
  my ($self, $args_ref) = @_;

  my $username = $args_ref->{username};
  my $password = $args_ref->{password};
  my $database = $args_ref->{database};

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
  my $sql_statement = qq{
  select d01gsi,d01ort,d01ex,d01av,d01rv,d01katkey,d01mtyp,d01skond 

  from $database.sisis.d01buch 

  where d01bnr = ? 
    and d01status = 4 

  order by d01rv asc
  };

  my $request=$self->{dbh}->prepare($sql_statement);
  $request->execute($username) or $logger->error_die($DBI::errstr);
  
  my @borrowlist=();
  
  while (my $res=$request->fetchrow_hashref()){
    
    my $katkey         = $res->{'d01katkey'};
    my $mtyp           = $res->{'d01mtyp'};    
    my $ausleihdatum   = OLWS::Common::Utils::conv_date($res->{'d01av'});
    my $rueckgabedatum = OLWS::Common::Utils::conv_date($res->{'d01rv'});    

    my $signatur       = $res->{'d01ort'};
    
    if ($res->{'d01ex'}){
      $signatur=$signatur.$res->{'d01ex'};
    }

    $signatur           = ($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$signatur)):decode("iso-8859-1",$signatur);

    my $mediennummer   = ($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$res->{'d01gsi'})):decode("iso-8859-1",$res->{'d01gsi'});

    my $title_ref = get_short_title({
	katkey   => $katkey,
	mtyp     => $mtyp,
	dbh      => $self->{dbh},
	database => $database,
	sikfstab => $self->{sikfstab},
	});

    my $singleborrow_ref = SOAP::Data->name(MediaItem  => \SOAP::Data->value(
		SOAP::Data->name(Katkey          => $katkey)->type('string'),
		SOAP::Data->name(Verfasser       => $title_ref->{Verfasser})->type('string'),
		SOAP::Data->name(Titel           => $title_ref->{Titel})->type('string'),
		SOAP::Data->name(EJahr           => $title_ref->{EJahr})->type('string'),
		SOAP::Data->name(Signatur        => $signatur)->type('string'),
		SOAP::Data->name(MTyp            => $mtyp)->type('string'),
		SOAP::Data->name(Mediennummer    => $mediennummer)->type('string'),
		SOAP::Data->name(AusleihDatum    => $ausleihdatum)->type('string'),
		SOAP::Data->name(RueckgabeDatum  => $rueckgabedatum)->type('string'),
	));
    
    push @borrowlist, $singleborrow_ref;
  }

  $request->finish;
  
  return SOAP::Data->name(BorrowList  => SOAP::Data->value(\@borrowlist));
}

# Aktive Ausleihen

sub get_idn_of_borrows {
  my ($self, $args_ref) = @_;

  my $username = $args_ref->{username};
  my $dept     = $args_ref->{dept};
  my $password = $args_ref->{password};
  my $database = $args_ref->{database};

  # Log4perl logger erzeugen

  my $logger = get_logger();

  my $sql_statement = "";
  my $sql_arg       = "";
  if ($username){
    $sql_statement = qq{
      select d01katkey 

      from $database.sisis.d01buch 

      where d01bnr = ? 
    };
    $sql_arg = $username;
  }
  elsif ($dept){
    $sql_statement = qq{
      select d01katkey 

      from $database.sisis.d01buch 

      where d01abtlg = ? 
    };
    $sql_arg = $dept;
  }
  
  my $request=$self->{dbh}->prepare($sql_statement);
  $request->execute($sql_arg) or $logger->error_die($DBI::errstr);

  my @borrowlist=();
  
  while (my $res=$request->fetchrow_hashref()){
    
    my $katkey=$res->{'d01katkey'};
    
    push @borrowlist, SOAP::Data->name(MediaItem  => \SOAP::Data->value(
		SOAP::Data->name(Katkey          => $katkey)->type('string'),
               	));
  }

  $request->finish;

  return SOAP::Data->name(BorrowList  => SOAP::Data->value(\@borrowlist));
}

sub make_reservation {
  my ($class, $args_ref) = @_;

  my $username     = $args_ref->{username};
  my $password     = $args_ref->{password};
  my $database     = $args_ref->{database};
  my $mediennummer = $args_ref->{mediennummer};
  my $zweigstelle  = $args_ref->{zweigstelle};
  my $ausgabeort   = $args_ref->{ausgabeort};

  # Log4perl logger erzeugen

  my $logger = get_logger();
 
  my $response_ref = OLWS::Common::SLNP::Circulation::make_reservation($username, $database, $mediennummer, $zweigstelle, $ausgabeort);

  return $response_ref;
}

sub cancel_reservation {
  my ($class, $args_ref) = @_;

  my $username     = $args_ref->{username};
  my $password     = $args_ref->{password};
  my $database     = $args_ref->{database};
  my $mediennummer = $args_ref->{mediennummer};
  my $zweigstelle  = $args_ref->{zweigstelle};

  # Log4perl logger erzeugen

  my $logger = get_logger();
 
  my $response_ref = OLWS::Common::SLNP::Circulation::cancel_reservation($username, $database, $mediennummer, $zweigstelle);

  return $response_ref;
}

sub make_order {
  my ($class, $args_ref) = @_;

  my $username     = $args_ref->{username};
  my $password     = $args_ref->{password};
  my $database     = $args_ref->{database};
  my $mediennummer = $args_ref->{mediennummer};
  my $zweigstelle  = $args_ref->{zweigstelle};
  my $ausgabeort   = $args_ref->{ausgabeort};

  # Log4perl logger erzeugen

  my $logger = get_logger();
 
  my $response_ref = OLWS::Common::SLNP::Circulation::make_order($username, $database, $mediennummer, $zweigstelle, $ausgabeort);

  return $response_ref;
}

sub renew_loans {
  my ($class, $args_ref) = @_;

  my $username     = $args_ref->{username};
  my $password     = $args_ref->{password};
  my $database     = $args_ref->{database};

  # Log4perl logger erzeugen

  my $logger = get_logger();
 
  my $response_ref = OLWS::Common::SLNP::Circulation::renew_loans($username, $database);

  return $response_ref;
}

sub get_short_title {
    my ($arg_ref) = @_;
    
    # Set defaults
    my $katkey  = exists $arg_ref->{katkey}
        ? $arg_ref->{katkey}        : undef;

    my $mtyp         = exists $arg_ref->{mtyp}
        ? $arg_ref->{mtyp}          : undef;
    my $dbh          = exists $arg_ref->{dbh}
        ? $arg_ref->{dbh}           : undef;
    my $database     = exists $arg_ref->{database}
        ? $arg_ref->{database}      : undef;
    my $sikfstab_ref = exists $arg_ref->{sikfstab}
        ? $arg_ref->{sikfstab}      : undef;
    
    my $titel_ref=undef;

    if ($mtyp eq "99"){
      $titel_ref=OLWS::Sisis::Data::get_titzfl_by_katkey($dbh,$database,$katkey);
    }
    else {
      $titel_ref=OLWS::Sisis::Data::get_titdupref_by_katkey($dbh,$database,$katkey);
    
      unless (defined($titel_ref)){
        $titel_ref=OLWS::Sisis::Data::get_titref_by_katkey($sikfstab_ref,$dbh,$database,$katkey);
      }
    }
    
    my %titel=%$titel_ref;
    
    my @verfasserkat=(
                      '0100.001',
                      '0100.002',
                      '0100.003',
                      '0101.001',
                      '0101.002',
                      '0101.003',
                      '0101.004',
                      '0200.001',
                      '0200.002',
                      '0200.003',
                      '0201.001',
                      '0201.002',
                      '0201.003',
                     );

    my @verfasserarray=();
    
    foreach my $kat (@verfasserkat){    
      push @verfasserarray, $titel{$kat} if ($titel{$kat});
    }
    
    my $verfasser=join(" ; ",@verfasserarray);
    
    my $hst="";
    if ($titel{'0331.001'}){
      $hst=$titel{'0331.001'};
    }
    elsif ($titel{'0331.002'}){
      $hst=$titel{'0331.002'};
    }
    elsif ($titel{'0089.001'}){
      $hst=$titel{'0089.001'};
      if ($titel{'0451.001'}){
	$hst=$titel{'0451.001'}." / ".$hst;
      }
      elsif ($titel{'0451.002'}){
	$hst=$titel{'0451.002'}." / ".$hst;
      }
      elsif ($titel{'0451.003'}){
	$hst=$titel{'0451.003'}." / ".$hst;
      }
      else {
	
	# Jetzt versuchen wir es beim uebergeordneten Titel
	
	my $titelgtf_ref=OLWS::Sisis::Data::get_titref_by_katkey($sikfstab_ref,$dbh,$database,$titel{'0004.001'});
	
	my %titelgtf=%$titelgtf_ref;
	
	if ($titelgtf{'0331.001'}){
	  $hst=$titelgtf{'0331.001'}." / ".$hst;
	}
	elsif ($titelgtf{'0331.002'}){
	  $hst=$titelgtf{'0331.002'}." / ".$hst;
	}
	my @verfassergtfarray=();
	if (!$verfasser){
	  foreach my $kat (@verfasserkat){    
	    push @verfassergtfarray, $titelgtf{$kat} if ($titelgtf{$kat});
	  }
	  $verfasser=join(" ; ",@verfassergtfarray);
	}
      }
    }
    
    my $ejahr=$titel{'0425.001'};

    return {
         Verfasser => $verfasser,
         Titel     => $hst,
         EJahr     => $ejahr,
    }
}

sub DESTROY {
    my $self = shift;

    return if (!defined $self->{dbh});

    $self->{dbh}->disconnect();

    return;
}

1;
