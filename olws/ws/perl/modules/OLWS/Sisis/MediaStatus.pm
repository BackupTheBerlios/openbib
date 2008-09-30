#####################################################################
#
#  Open Library WebServices
#
#  OLWS::Sisis::MediaStatus
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

package OLWS::Sisis::MediaStatus;

use strict;
use warnings;

use Log::Log4perl qw(get_logger :levels);
use Encode qw/encode decode/;

use DBI;

use OLWS::Sisis::Config;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace

use vars qw(%config);

*config=\%OLWS::Sisis::Config::config;

sub get_mediastatus {
  my ($class, $args_ref) = @_;

  my $katkey   = $args_ref->{katkey};
  my $database = $args_ref->{database};

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
  $logger->info("Request for Database: $database - Katkey: $katkey");

  my $entl_map_ref = {
      'X' => 0, # nein
      ' ' => 1, # ja
      'L' => 2, # Lesesaal
      'B' => 3, # Bes. Lesesaal
      'W' => 4, # Wochenende
  };
  
  #####################################################################
  # Verbindung zur SQL-Datenbank herstellen
  
  my $dbh=DBI->connect("DBI:$config{dbimodule}:dbname=$database;server=$config{dbserver};host=$config{dbhost};port=$config{dbport}", $config{dbuser}, $config{dbpasswd}) or $logger->error_die($DBI::errstr);

  my $sql_statement = qq{
  select * 

  from $database.sisis.d50zweig
  };
  
  my $request=$dbh->prepare($sql_statement);
  $request->execute() or $logger->error_die($DBI::errstr);
  
  my %zweig=();
  while (my $res=$request->fetchrow_hashref()){
    $zweig{$res->{'d50zweig'}}{Bezeichnung}=$res->{'d50bezeich'};
  }
  
  $sql_statement = qq{
  select * 

  from $database.sisis.d60abteil
  };

  $request=$dbh->prepare($sql_statement);
  $request->execute() or $logger->error_die($DBI::errstr);
  
  my %abteilung=();
  while (my $res=$request->fetchrow_hashref()){
    $abteilung{$res->{'d60zweig'}}{$res->{'d60abt'}}=$res->{'d60bezeich'};
  }

  $sql_statement = qq{
  select * 

  from $database.sisis.d63mtyp
  };

  $request=$dbh->prepare($sql_statement);
  $request->execute() or $logger->error_die($DBI::errstr);
  
  my $mtyp_ref = {};
  while (my $res=$request->fetchrow_hashref()){
    $mtyp_ref->{$res->{'d63mtyp'}} = {
         vmanz     => $res->{'d63anzvm'},
         sotext    => $res->{'d63sotext'},
         helptext  => $res->{'d63helptest'},
    };
  }
  
  $sql_statement = qq{
  select d01aort,d01gsi,d01ort,d01entl,d01mtyp,d01ex,d01status,d01skond,d01vmanz,d01rv,d01abtlg,d01zweig,d01bnr 

  from $database.sisis.d01buch

  where d01katkey = ? 
  };

  $request=$dbh->prepare($sql_statement);
  $request->execute($katkey) or $logger->error_die($DBI::errstr);;
  
  my @medialist = ();
  while (my $res=$request->fetchrow_hashref()){
    my $mediennr   = $res->{'d01gsi'};
    my $signatur   = $res->{'d01ort'};
    my $exemplar   = $res->{'d01ex'};
    my $rueckgabe  = $res->{'d01rv'};
    my $entl       = $res->{'d01entl'};
    my $status     = $res->{'d01status'};
    my $skond      = $res->{'d01skond'};
    my $abteilung  = $res->{'d01abtlg'};
    my $mtyp       = $res->{'d01mtyp'};
    my $bnr        = $res->{'d01bnr'};
    my $zweignr    = $res->{'d01zweig'};
    my $vmanz      = $res->{'d01vmanz'};
    my $ausgabeort = $res->{'d01aort'};
    my $zweigst    = "";

    my $statusstring   = "";
    my $standortstring = "";
    my $vormerkbar     = 0;
    my $opactext       = (exists $mtyp_ref->{$mtyp}{sotext})?$mtyp_ref->{$mtyp}{sotext}:'';

    if ($vmanz < $mtyp_ref->{$mtyp}{vmanz}){
       $vormerkbar   = 1;
    }

    if ($abteilung{"$zweignr"}{"$abteilung"}){
      $standortstring=$abteilung{"$zweignr"}{"$abteilung"};
    }
    
    if ($zweig{"$zweignr"}{Bezeichnung}){
      $standortstring=$zweig{"$zweignr"}{Bezeichnung}." / $standortstring";
    }

    if    ($entl_map_ref->{$entl} == 0){
      $statusstring="nicht entleihbar";
    }
    elsif ($entl_map_ref->{$entl} == 1){
    	if ($status eq "0"){
            $statusstring="bestellbar";
        }
        elsif ($status eq "2"){
            $statusstring="entliehen"; # Sonderwunsch. Eigentlich: bestellt
        }
        elsif ($status eq "4"){
            $statusstring="entliehen";
        }
        else {
            $statusstring="unbekannt";
        }
    }
    elsif ($entl_map_ref->{$entl} == 2){
      $statusstring="nur in Lesesaal bestellbar";
    }
    elsif ($entl_map_ref->{$entl} == 3){
      $statusstring="nur in bes. Lesesaal bestellbar";
    }
    elsif ($entl_map_ref->{$entl} == 4){
      $statusstring="nur Wochenende";
    }
    else {
      $statusstring="unbekannt";
    }

    # Sonderkonditionen

    if ($skond eq "16"){
      $statusstring="verloren";
    }
    elsif ($skond eq "32"){
      $statusstring="vermi&szlig;t";
    }

    $rueckgabe=~s/12:00AM//;
    
    $standortstring="-" unless ($standortstring);

    my $d39sql_statement = qq{
       select d39fusstext

       from $database.sisis.d39fussnoten

       where d39gsi = ?
         AND d39ex = ?
         AND d39fussart = 1

       order by d39fussnr
  };

    my $request2=$dbh->prepare($d39sql_statement);
    $request2->execute($mediennr,$exemplar) or $logger->error_die($DBI::errstr);;
    
    $logger->info("Fussnoten fuer Mediennr:$mediennr: Exemplar:$exemplar:");
    my $fussnote = "";
	
    while (my $res2=$request2->fetchrow_hashref){
        $fussnote.=$res2->{d39fusstext};
    }
    
    $request2->finish();

    
    my $singleex_ref = SOAP::Data->name(MediaItem  => \SOAP::Data->value(
		SOAP::Data->name(Mediennr       => encode("utf-8",decode("iso-8859-1",$mediennr)))->type('string'),
		SOAP::Data->name(Zweigstelle    => encode("utf-8",decode("iso-8859-1",$zweignr)))->type('string'),
		SOAP::Data->name(Signatur       => encode("utf-8",decode("iso-8859-1",$signatur)))->type('string'),
		SOAP::Data->name(Exemplar       => encode("utf-8",decode("iso-8859-1",$exemplar)))->type('string'),
		SOAP::Data->name(Abteilungscode => encode("utf-8",decode("iso-8859-1",$abteilung)))->type('string'),
		SOAP::Data->name(Standort       => encode("utf-8",decode("iso-8859-1",$standortstring)))->type('string'),
		SOAP::Data->name(Status         => encode("utf-8",decode("iso-8859-1",$statusstring)))->type('string'),
		SOAP::Data->name(Statuscode     => encode("utf-8",decode("iso-8859-1",$status)))->type('string'),
		SOAP::Data->name(Opactext       => encode("utf-8",decode("iso-8859-1",$opactext)))->type('string'),
		SOAP::Data->name(Entleihbarkeit => $entl_map_ref->{$entl})->type('int'),
		SOAP::Data->name(Vormerkbarkeit => $vormerkbar)->type('int'),
		SOAP::Data->name(Rueckgabe      => encode("utf-8",decode("iso-8859-1",$rueckgabe)))->type('string'),
		SOAP::Data->name(Ausgabeort     => encode("utf-8",decode("iso-8859-1",$ausgabeort)))->type('string'),
	));
    
    push @medialist, $singleex_ref;
  }


  # Wenn noch keine Buchdaten, dann vielleicht nur bestellt?
  if (!@medialist){
#    if (0 == 1){
	# Bestellungen beim Lieferanten/Neuanschaffungen
	$logger->info("Keine Buchdaten. Suche Bestelldaten");

	$sql_statement = qq{
     select buch.statusbuch as buchstatus ,best.bsdatum as bestelldatum 

     from $database.sisis.bestellung as best, $database.sisis.acq_band as band, $database.sisis.acq_buch as buch

     where band.katkey=? 
       and band.bnr=best.bnr 
       and best.bnr=buch.bnr 
       and best.verarbcode=1 
       and buch.statusverarb=1 
       and buch.statusbest=1
  };

	$request=$dbh->prepare($sql_statement);
	$request->execute($katkey) or $logger->error_die($DBI::errstr);;
	
	while (my $res=$request->fetchrow_hashref()){
	    my $bestelldatum   = $res->{'bestelldatum'};
	    my $statuscode     = $res->{'buchstatus'};

	    my $singleex_ref = SOAP::Data->name(AquisitionItem  => \SOAP::Data->value(
						    SOAP::Data->name(Mediennr       => '')->type('string'),
						    SOAP::Data->name(Zweigstelle    => '0')->type('string'),
						    SOAP::Data->name(Signatur       => '')->type('string'),
						    SOAP::Data->name(Exemplar       => '')->type('string'),
						    SOAP::Data->name(Abteilungscode => '')->type('string'),
                                                    SOAP::Data->name(Standortcode   => '')->type('string'),
						    SOAP::Data->name(Standort       => '')->type('string'),
						    SOAP::Data->name(Status         => '')->type('string'),
						    SOAP::Data->name(Statuscode     => '')->type('string'),
						    SOAP::Data->name(AquisitionStatuscode => "$statuscode")->type('string'),
						    SOAP::Data->name(Opactext       => '')->type('string'),
						    SOAP::Data->name(Fussnote       => '')->type('string'),
						    SOAP::Data->name(Entleihbarkeit => 0)->type('int'),
						    SOAP::Data->name(Vormerkbarkeit => 0)->type('int'),
						    SOAP::Data->name(Rueckgabe      => '')->type('string'),
						    SOAP::Data->name(Ausgabeort     => '')->type('string'),
						));
	    
	    push @medialist, $singleex_ref;
	    $logger->info("Erwerbungsdaten gefunden fuer Katkey: $katkey");
	}
    }
  
  return SOAP::Data->name(MediaList  => SOAP::Data->value(\@medialist));
}

1;
