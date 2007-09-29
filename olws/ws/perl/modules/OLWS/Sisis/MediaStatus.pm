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
  select d01aort,d01gsi,d01ort,d01entl,d01mtyp,d01ex,d01status,d01skond,d01rv,d01abtlg,d01zweig,d01bnr 

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
    my $standort   = $res->{'d01abtlg'};
    my $mtyp       = $res->{'d01mtyp'};
    my $bnr        = $res->{'d01bnr'};
    my $zweignr    = $res->{'d01zweig'};
    my $ausgabeort = $res->{'d01aort'};
    my $zweigst    = "";

    my $statusstring="";

    if ($abteilung{"$zweignr"}{"$standort"}){
      $standort=$abteilung{"$zweignr"}{"$standort"};
    }
    
    if ($zweig{"$zweignr"}{Bezeichnung}){
      $standort=$zweig{"$zweignr"}{Bezeichnung}." / $standort";
    }
    
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

    # Sonderkonditionen

    if ($skond eq "16"){
      $statusstring="verloren";
    }
    elsif ($skond eq "32"){
      $statusstring="vermi&szlig;t";
    }

    if ($zweignr == 0){    
      if ($signatur=~/^19A/ || $signatur=~/^2\dA/ || $signatur=~/3[0-3]A/){
        if ($statusstring eq "bestellbar"){
	  $statusstring="<a href=\"http://www.ub.uni-koeln.de/service/ausleihabc/sab/index_ger.html\" target=\"_blank\">SAB</a> / ausleihbar";
        }
        else {
	  $statusstring="<a href=\"http://www.ub.uni-koeln.de/service/ausleihabc/sab/index_ger.html\" target=\"_blank\">SAB</a> / vormerkbar";
        }
      }
    
      if ($standort=~/Lehrbuchsammlung/){
        if ($statusstring eq "bestellbar"){
          $statusstring="<a href=\"http://www.ub.uni-koeln.de/service/ausleihabc/lbs/index_ger.html\" target=\"_blank\">LBS</a> / ausleihbar";
        }
        else {
          $statusstring="<a href=\"http://www.ub.uni-koeln.de/service/ausleihabc/lbs/index_ger.html\" target=\"_blank\">LBS</a> / entliehen";
        }
      }
      elsif ($standort=~/Lesesaal/){
        $statusstring="<a href=\"http://www.ub.uni-koeln.de/service/ausleihabc/ls/index_ger.html\" target=\"_blank\">LS</a> / Pr&auml;senzbestand";
      }
    
    }
    elsif ($zweignr == 4){    
      if ($standort=~/Lehrbuchsammlung/){
        if ($statusstring eq "bestellbar"){
           $statusstring="<a href=\"http://www.ub.uni-koeln.de/bibliothek/kontakt/zeiten/index_ger.html#e1693\" target=\"_blank\">LBS</a> / ausleihbar";
        }
        else {
           $statusstring="<a href=\"http://www.ub.uni-koeln.de/bibliothek/kontakt/zeiten/index_ger.html#e1693\" target=\"_blank\">LBS</a> / entliehen";
        }
      }
      elsif ($standort=~/Lesesaal/){
        $statusstring="LS / Pr&auml;senzbestand";
      }
    }

    # Spezielle Enleiher

    # EDZ
    if ($bnr eq "D00000572#H"){
        $statusstring="<a href=\"http://www.ub.uni-koeln.de/edz/content/index_ger.html\" target=\"_blank\">EDZ</a> / einsehbar";
        $standort="EDZ";
    }

    $rueckgabe=~s/12:00AM//;
    
    $standort="-" unless ($standort);
    
    my $singleex_ref = SOAP::Data->name(MediaItem  => \SOAP::Data->value(
		SOAP::Data->name(Mediennr    => $mediennr)->type('string'),
		SOAP::Data->name(Zweigstelle => $zweignr)->type('string'),
		SOAP::Data->name(Signatur    => $signatur)->type('string'),
		SOAP::Data->name(Exemplar    => $exemplar)->type('string'),
		SOAP::Data->name(Standort    => $standort)->type('string'),
		SOAP::Data->name(Status      => $statusstring)->type('string'),
		SOAP::Data->name(Statuscode  => $status)->type('string'),
		SOAP::Data->name(Rueckgabe   => $rueckgabe)->type('string'),
		SOAP::Data->name(Ausgabeort  => $ausgabeort)->type('string'),
	));
    
    push @medialist, $singleex_ref;
  }

  return SOAP::Data->name(MediaList  => SOAP::Data->value(\@medialist));
}

1;
