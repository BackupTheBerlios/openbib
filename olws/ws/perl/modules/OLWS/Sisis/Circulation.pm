#####################################################################
#
#  Open Library WebServices
#
#  OLWS::Sisis::Circulation
#
#  Dieses File ist (C) 2005-2006 Oliver Flimm <flimm@openbib.org>
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

use DBI;

use OLWS::Sisis::Data;
use OLWS::Sisis::Config;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace

use vars qw(%config);

*config=\%OLWS::Sisis::Config::config;

# Verlaengerungen

sub get_renewals {

  return;
}

# Bestellungen

sub get_orders {
  my ($class, $username, $password, $database) = @_;
  
  # Log4perl logger erzeugen
  
  my $logger = get_logger();
  
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
  
  my $dbh=DBI->connect("DBI:$config{dbimodule}:dbname=$database;server=$config{dbserver};host=$config{dbhost};port=$config{dbport}", $config{dbuser}, $config{dbpasswd}) or $logger->error_die($DBI::errstr);
  
  my $result=$dbh->prepare("select d01gsi,d01ort,d01ex,d01av,d01rv,d01aufnahme,d01katkey,d01mtyp,d01skond from $database.sisis.d01buch where d01bnr = ? and d01status = 2 order by d01rv asc");
  
  $result->execute($username) or $logger->error_die($DBI::errstr);
  
  my $sikfstabref=OLWS::Sisis::Data::get_sikfstabref($dbh,$database);
  
  my @bestellliste=();
  
  while (my $res=$result->fetchrow_hashref()){
    
    my $katkey=$res->{'d01katkey'};
    
    my $mtyp=$res->{'d01mtyp'};
    my $skond=$res->{'d01skond'};
    
    # kein Status    
    if ($skond == 0){
      $skond="bestellt";
    }	
    # Vormerkung priv. Gruppe
    elsif ($skond == 1){
      $skond="Vormerkung priv. Gruppe";
    }	
    # Besondere Leihfrist
    elsif ($skond == 2){
      $skond="Besondere Leihfrist";
    }	
    # Ausleihe mit Medienparameter
    elsif ($skond == 4){
      $skond="Ausleihe mit Medienparameter";
    }	
    # verlustgebucht
    elsif ($skond == 16){
      $skond="verlustgebucht";
    }	
    # PFL eingangsverbucht
    elsif ($skond == 64 ){
      $skond="abholbar";
    }	
    # PFL auf R&uuml;ckversand
    elsif ($skond == 128 ){
      $skond="PFL auf R&uuml;ckversand";
    }	
    # Geb&uuml;hren u. Mahnungen vorhanden
    elsif ($skond == 256 ){
      $skond="Geb&uuml;hren u. Mahnungen vorhanden";
    }	
    # Mahnung ohne Geb&uuml;hr vorhanden
    elsif ($skond == 512){
      $skond="Mahnung ohne Geb&uuml;hr vorhanden";
    }	
    # PFL wurde sondiert
    elsif ($skond == 1024){
      $skond="PFL wurde sondiert";
    }	
    # r&uuml;ckgefordert wg. Benutzersperre
    elsif ($skond == 2048){
      $skond="r&uuml;ckgefordert wg. Benutzersperre";
    }	
    # aktuelle Geb&uuml;hren vorhanden
    elsif ($skond == 4096){
      $skond="aktuelle Geb&uuml;hren vorhanden";
    }	
    # Magazinbestellung
    elsif ($skond == 8192){
      $skond="bestellt";
    }	
    # offene OPAC PFL-Bestellung
    elsif ($skond == 16384){
      $skond="offene OPAC PFL-Bestellung";
    }	
    # abgesagte PFL-Bestellung
    elsif ($skond == 32748){
      $skond="abgesagte PFL-Bestellung";
    }	
    else {
      $skond="unbekannt";
    }	
    
    my ($month,$day,$year)=$res->{'d01aufnahme'}=~m/^([A-Za-z]+)\s+(\d+)\s+(\d+)\s+/;
    $day=~s/^(\d)$/0$1/;
    $month=~s/^(\d)$/0$1/;
    my $bestelldatumpfl=$day.".".$monthtab{$month}.".".$year;
    
    ($month,$day,$year)=$res->{'d01av'}=~m/^([A-Za-z]+)\s+(\d+)\s+(\d+)\s+/;
    $day=~s/^(\d)$/0$1/;
    $month=~s/^(\d)$/0$1/;
    my $bestelldatum=$day.".".$monthtab{$month}.".".$year;
    
    if ($mtyp eq "99"){
      $bestelldatum=$bestelldatumpfl;
    }
    
    my $signatur=$res->{'d01ort'};
    
    if ($res->{'d01ex'}){
      $signatur=$signatur.$res->{'d01ex'};
    }
    
    my $mediennummer=$res->{'d01gsi'};
    
    my $singlebestellung={
			  Katkey          => $katkey,
			  Signatur        => $signatur,
			  MTyp            => $mtyp,
			  Status          => $skond,
			  Mediennummer    => $mediennummer,
			  BestellDatum    => $bestelldatum,
			 };
    
    
    push @bestellliste, $singlebestellung;
  }
  
  for (my $i=0;$i<=$#bestellliste;$i++){
    my $katkey=$bestellliste[$i]{Katkey};
    my $mtyp=$bestellliste[$i]{MTyp};
    
    
    my $titelref=undef;
    
    if ($mtyp eq "99"){
      $titelref=OLWS::Sisis::Data::get_titzfl_by_katkey($dbh,$database,$katkey);
    }
    else {
      $titelref=OLWS::Sisis::Data::get_titdupref_by_katkey($dbh,$database,$katkey);
      
      unless (defined($titelref)){
        $titelref=OLWS::Sisis::Data::get_titref_by_katkey($sikfstabref,$dbh,$database,$katkey);
      }
    }
    
    my %titel=%$titelref;
    
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
	
	my $titelgtfref=OLWS::Sisis::Data::get_titref_by_katkey($sikfstabref,$dbh,$database,$titel{'0004.001'});
	
	my %titelgtf=%$titelgtfref;
	
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
    
    $bestellliste[$i]{Verfasser}=$verfasser;
    $bestellliste[$i]{Titel}=$hst;
    $bestellliste[$i]{EJahr}=$ejahr;
  }
  
  return \@bestellliste;
}


# Vormerkungen

sub get_reservations {
  my ($class, $username, $password, $database) = @_;

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
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
  
  my $dbh=DBI->connect("DBI:$config{dbimodule}:dbname=$database;server=$config{dbserver};host=$config{dbhost};port=$config{dbport}", $config{dbuser}, $config{dbpasswd}) or $logger->error_die($DBI::errstr);
  
  my $result=$dbh->prepare("select * from $database.sisis.d04vorm where d04bnr = ?");
  $result->execute($username) or $logger->error_die($DBI::errstr);
  
  my $sikfstabref=OLWS::Sisis::Data::get_sikfstabref($dbh,$database);
  
  my @vormerkliste=();
  
  while (my $res=$result->fetchrow_hashref()){
    
    my $katkey=$res->{'d04katkey'};
    
    my $stelle=-1;

    my $result2=$dbh->prepare("select * from $database.sisis.d04vorm where d04katkey = ? order by d04vmnr");
    $result2->execute($katkey) or $logger->error_die($DBI::errstr);

    my $counter=1;

    while (my $res2=$result2->fetchrow_hashref()){

      my $bnr=$res2->{'d04bnr'};

      if ($bnr eq $username){
        $stelle=$counter;
        last;
      }

      $counter++;
    }

    my ($month,$day,$year)=$res->{'d04vmdatum'}=~m/^([A-Za-z]+)\s+(\d+)\s+(\d+)\s+/;
    $day=~s/^(\d)$/0$1/;
    $month=~s/^(\d)$/0$1/;
    my $vormerkdatum=$day.".".$monthtab{$month}.".".$year;
    
    ($month, $day,$year)=$res->{'d04aufrecht'}=~m/^([A-Za-z]+)\s+(\d+)\s+(\d+)\s+/;
    $day=~s/^(\d)$/0$1/;
    $month=~s/^(\d)$/0$1/;
    my $aufrechtdatum=$day.".".$monthtab{$month}.".".$year;
    
    my $mediennummer=$res->{'d04gsi'};
    
    my $singlevormerkung={
			  Katkey          => $katkey,
			  Mediennummer    => $mediennummer,
			  VormerkDatum    => $vormerkdatum,
			  AufrechtDatum   => $aufrechtdatum,
			  Stelle          => $stelle,
			 };
    
    push @vormerkliste, $singlevormerkung;
  }
  
  for (my $i=0;$i<=$#vormerkliste;$i++){
    my $katkey=$vormerkliste[$i]{Katkey};
    
    
    my $titelref=undef;
    
    $titelref=OLWS::Sisis::Data::get_titdupref_by_katkey($dbh,$database,$katkey);
    
    unless (defined($titelref)){
      $titelref=OLWS::Sisis::Data::get_titref_by_katkey($sikfstabref,$dbh,$database,$katkey);
    }
    
    my %titel=%$titelref;
    
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
	
	my $titelgtfref=OLWS::Sisis::Data::get_titref_by_katkey($sikfstabref,$dbh,$database,$titel{'0004.001'});
	
	my %titelgtf=%$titelgtfref;
	
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
    
    $vormerkliste[$i]{Verfasser}=$verfasser;
    $vormerkliste[$i]{Titel}=$hst;
    $vormerkliste[$i]{EJahr}=$ejahr;
  }
  
  return \@vormerkliste;
}

# Mahnungen

sub get_reminders {
  my ($class, $username, $password, $database) = @_;

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
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
  
  my $dbh=DBI->connect("DBI:$config{dbimodule}:dbname=$database;server=$config{dbserver};host=$config{dbhost};port=$config{dbport}", $config{dbuser}, $config{dbpasswd}) or $logger->error_die($DBI::errstr);
  
  my $result=$dbh->prepare("select * from $database.sisis.d03geb where d03bnr = ? and d03stat != 4128");
  $result->execute($username) or $logger->error_die($DBI::errstr);
  
  my $sikfstabref=OLWS::Sisis::Data::get_sikfstabref($dbh,$database);
  
  my @mahnungsliste=();
  
  while (my $res=$result->fetchrow_hashref()){
    
    my $katkey=$res->{'d03katkey'};
    
    my $saeumnisgebuehr=$res->{'d03gebu'};
    my $mahngebuehr=$res->{'d03mahn'};
    my $mtyp=$res->{'d03mtyp'};
    
    my ($month,$day,$year)=$res->{'d03von'}=~m/^([A-Za-z]+)\s+(\d+)\s+(\d+)\s+/;
    $day=~s/^(\d)$/0$1/;
    $month=~s/^(\d)$/0$1/;
    my $ausleihdatum=$day.".".$monthtab{$month}.".".$year;
    
    ($month, $day,$year)=$res->{'d03lfe'}=~m/^([A-Za-z]+)\s+(\d+)\s+(\d+)\s+/;
    $day=~s/^(\d)$/0$1/;
    $month=~s/^(\d)$/0$1/;
    my $leihfristende=$day.".".$monthtab{$month}.".".$year;

    if ($mtyp == 99){
      $leihfristende="-";
    }
    
    my $mediennummer=$res->{'d03gsi'};
    
    my $singlemahnung={
		       Katkey          => $katkey,
		       Mediennummer    => $mediennummer,
		       MTyp            => $mtyp,
		       AusleihDatum    => $ausleihdatum,
		       Leihfristende   => $leihfristende,
		       Mahngebuehr     => $mahngebuehr,
		       Saeumnisgebuehr => $saeumnisgebuehr,
		      };
    
    push @mahnungsliste, $singlemahnung;
  }
  
  for (my $i=0;$i<=$#mahnungsliste;$i++){
    my $katkey=$mahnungsliste[$i]{Katkey};
    my $mtyp=$mahnungsliste[$i]{MTyp};
        
    my $titelref=undef;

    if ($mtyp eq "99"){
      $titelref=OLWS::Sisis::Data::get_titzfl_by_katkey($dbh,$database,$katkey);
    }
    else {
      $titelref=OLWS::Sisis::Data::get_titdupref_by_katkey($dbh,$database,$katkey);
    
      unless (defined($titelref)){
        $titelref=OLWS::Sisis::Data::get_titref_by_katkey($sikfstabref,$dbh,$database,$katkey);
      }
    }

    my %titel=%$titelref;
    
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
	
	my $titelgtfref=OLWS::Sisis::Data::get_titref_by_katkey($sikfstabref,$dbh,$database,$titel{'0004.001'});
	
	my %titelgtf=%$titelgtfref;
	
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
    
    $mahnungsliste[$i]{Verfasser}=$verfasser;
    $mahnungsliste[$i]{Titel}=$hst;
    $mahnungsliste[$i]{EJahr}=$ejahr;
  }
  
  return \@mahnungsliste;
}

# Aktive Ausleihen

sub get_borrows {
  
  my ($class, $username, $password, $database) = @_;

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
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
  
  my $dbh=DBI->connect("DBI:$config{dbimodule}:dbname=$database;server=$config{dbserver};host=$config{dbhost};port=$config{dbport}", $config{dbuser}, $config{dbpasswd}) or $logger->error_die($DBI::errstr);
  
  my $result=$dbh->prepare("select d01gsi,d01ort,d01ex,d01av,d01rv,d01katkey,d01mtyp,d01skond from $database.sisis.d01buch where d01bnr = ? and d01status = 4 order by d01rv asc");
  $result->execute($username) or $logger->error_die($DBI::errstr);
  
  my $sikfstabref=OLWS::Sisis::Data::get_sikfstabref($dbh,$database);
  
  my @ausleihliste=();
  
  while (my $res=$result->fetchrow_hashref()){
    
    my $katkey=$res->{'d01katkey'};
    my $mtyp=$res->{'d01mtyp'};
    
    my ($month,$day,$year)=$res->{'d01av'}=~m/^([A-Za-z]+)\s+(\d+)\s+(\d+)\s+/;
    $day=~s/^(\d)$/0$1/;
    $month=~s/^(\d)$/0$1/;
    my $ausleihdatum=$day.".".$monthtab{$month}.".".$year;
    
    ($month, $day,$year)=$res->{'d01rv'}=~m/^([A-Za-z]+)\s+(\d+)\s+(\d+)\s+/;
    $day=~s/^(\d)$/0$1/;
    $month=~s/^(\d)$/0$1/;
    my $rueckgabedatum=$day.".".$monthtab{$month}.".".$year;
    
    my $signatur=$res->{'d01ort'};
    
    if ($res->{'d01ex'}){
      $signatur=$signatur.$res->{'d01ex'};
    }
    
    my $mediennummer=$res->{'d01gsi'};
    
    my $singleausleihe={
			Katkey          => $katkey,
			Signatur        => $signatur,
			MTyp            => $mtyp,
			Mediennummer    => $mediennummer,
			AusleihDatum    => $ausleihdatum,
			RueckgabeDatum  => $rueckgabedatum,
		       };
    
    push @ausleihliste, $singleausleihe;
  }
  
  for (my $i=0;$i<=$#ausleihliste;$i++){
    my $katkey=$ausleihliste[$i]{Katkey};
    my $mtyp=$ausleihliste[$i]{MTyp};
    
    
    my $titelref=undef;

    if ($mtyp eq "99"){
      $titelref=OLWS::Sisis::Data::get_titzfl_by_katkey($dbh,$database,$katkey);
    }
    else {
      $titelref=OLWS::Sisis::Data::get_titdupref_by_katkey($dbh,$database,$katkey);
    
      unless (defined($titelref)){
        $titelref=OLWS::Sisis::Data::get_titref_by_katkey($sikfstabref,$dbh,$database,$katkey);
      }
    }
    
    my %titel=%$titelref;
    
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
	
	my $titelgtfref=OLWS::Sisis::Data::get_titref_by_katkey($sikfstabref,$dbh,$database,$titel{'0004.001'});
	
	my %titelgtf=%$titelgtfref;
	
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
    
    $ausleihliste[$i]{Verfasser}=$verfasser;
    $ausleihliste[$i]{Titel}=$hst;
    $ausleihliste[$i]{EJahr}=$ejahr;
  }
  
  return \@ausleihliste;
}

# Aktive Ausleihen

sub get_idn_of_borrows {
  
  my ($class, $username, $password, $database) = @_;

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
  #####################################################################
  # Verbindung zur SQL-Datenbank herstellen
  
  my $dbh=DBI->connect("DBI:$config{dbimodule}:dbname=$database;server=$config{dbserver};host=$config{dbhost};port=$config{dbport}", $config{dbuser}, $config{dbpasswd}) or $logger->error_die($DBI::errstr);
  
  my $result=$dbh->prepare("select d01katkey from $database.sisis.d01buch where d01bnr = ? ");
  $result->execute($username) or $logger->error_die($DBI::errstr);
  
  my @ausleihliste=();
  
  while (my $res=$result->fetchrow_hashref()){
    
    my $katkey=$res->{'d01katkey'};
    
    push @ausleihliste, $katkey;
  }
    
  return \@ausleihliste;
}

1;
