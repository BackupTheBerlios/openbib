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

# Vormerkungen

sub get_reservations {
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
  
  my $result=$dbh->prepare("select * from $database.sisis.d04vorm where d04bnr = ?");
  $result->execute($username);
  
  my $sikfstabref=OLWS::Sisis::Data::get_sikfstabref($dbh,$database);
  
  my @vormerkliste=();
  
  while (my $res=$result->fetchrow_hashref()){
    
    my $katkey=$res->{'d04katkey'};
    
    my $stelle=$res->{'d04vmnr'};
    
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
  
  my $result=$dbh->prepare("select * from $database.sisis.d03geb where d03bnr = ?");
  $result->execute($username);
  
  my $sikfstabref=OLWS::Sisis::Data::get_sikfstabref($dbh,$database);
  
  my @mahnungsliste=();
  
  while (my $res=$result->fetchrow_hashref()){
    
    my $katkey=$res->{'d03katkey'};
    
    my $saeumnisgebuehr=$res->{'d03gebu'};
    my $mahngebuehr=$res->{'d03mahn'};
    
    my ($month,$day,$year)=$res->{'d03von'}=~m/^([A-Za-z]+)\s+(\d+)\s+(\d+)\s+/;
    $day=~s/^(\d)$/0$1/;
    $month=~s/^(\d)$/0$1/;
    my $ausleihdatum=$day.".".$monthtab{$month}.".".$year;
    
    ($month, $day,$year)=$res->{'d03lfe'}=~m/^([A-Za-z]+)\s+(\d+)\s+(\d+)\s+/;
    $day=~s/^(\d)$/0$1/;
    $month=~s/^(\d)$/0$1/;
    my $leihfristende=$day.".".$monthtab{$month}.".".$year;
    
    my $mediennummer=$res->{'d03gsi'};
    
    my $singlemahnung={
		       Katkey          => $katkey,
		       Mediennummer    => $mediennummer,
		       AusleihDatum    => $ausleihdatum,
		       Leihfristende   => $leihfristende,
		       Mahngebuehr     => $mahngebuehr,
		       Saeumnisgebuehr => $saeumnisgebuehr,
		      };
    
    push @mahnungsliste, $singlemahnung;
  }
  
  for (my $i=0;$i<=$#mahnungsliste;$i++){
    my $katkey=$mahnungsliste[$i]{Katkey};
    
    
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
    
    $mahnungsliste[$i]{Verfasser}=$verfasser;
    $mahnungsliste[$i]{Titel}=$hst;
    $mahnungsliste[$i]{EJahr}=$ejahr;
  }
  
  return \@mahnungsliste;
}

# Aktive Ausleihen

sub get_borrows {
  
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
  
  my $result=$dbh->prepare("select d01gsi,d01ort,d01ex,d01av,d01rv,d01katkey from $database.sisis.d01buch where d01bnr = ? order by d01rv asc");
  $result->execute($username);
  
  my $sikfstabref=OLWS::Sisis::Data::get_sikfstabref($dbh,$database);
  
  my @ausleihliste=();
  
  while (my $res=$result->fetchrow_hashref()){
    
    my $katkey=$res->{'d01katkey'};
    
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
			Mediennummer    => $mediennummer,
			AusleihDatum    => $ausleihdatum,
			RueckgabeDatum  => $rueckgabedatum,
		       };
    
    push @ausleihliste, $singleausleihe;
  }
  
  for (my $i=0;$i<=$#ausleihliste;$i++){
    my $katkey=$ausleihliste[$i]{Katkey};
    
    
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
    
    $ausleihliste[$i]{Verfasser}=$verfasser;
    $ausleihliste[$i]{Titel}=$hst;
    $ausleihliste[$i]{EJahr}=$ejahr;
  }
  
  return \@ausleihliste;
}

1;
