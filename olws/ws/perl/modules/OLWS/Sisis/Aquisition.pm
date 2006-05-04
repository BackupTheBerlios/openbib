#####################################################################
#
#  Open Library WebServices
#
#  OLWS::Sisis::Aquisition
#
#  Dieses File ist (C) 2006 Oliver Flimm <flimm@openbib.org>
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

package OLWS::Sisis::Aquisition;

use strict;
use warnings;

use Log::Log4perl qw(get_logger :levels);

use DBI;

use OLWS::Sisis::Config;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace

use vars qw(%config);

*config=\%OLWS::Sisis::Config::config;

sub get_recent_titids_by_acqgrp {
  
  my ($class, $database, $acqgrp, $limit) = @_;

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
  $logger->info("Request for Database: $database - ACQGrp: $acqgrp");
  
  #####################################################################
  # Verbindung zur SQL-Datenbank herstellen
  
  my $dbh=DBI->connect("DBI:$config{dbimodule}:dbname=$database;server=$config{dbserver};host=$config{dbhost};port=$config{dbport}", $config{dbuser}, $config{dbpasswd}) or $logger->error_die($DBI::errstr);

  $dbh->do("set rowcount $limit");
  
  my $result=$dbh->prepare("select distinct katkey from $database.sisis.rechkopf, $database.sisis.rechbuch, $database.sisis.acq_band, $database.sisis.bestellung where $database.sisis.rechkopf.rnr = $database.sisis.rechbuch.rnr and $database.sisis.rechbuch.bnr   = $database.sisis.acq_band.bnr and $database.sisis.rechbuch.band  = $database.sisis.acq_band.band and $database.sisis.rechbuch.bnr   = $database.sisis.bestellung.bnr and not (verarbcode = 2) and $database.sisis.acq_band.fach = ? order by ivdatum DESC");
  $result->execute($acqgrp) or $logger->error_die($DBI::errstr);
  
  my @titlist=();
  while (my $res=$result->fetchrow_hashref()){
    push @titlist, $res->{katkey};
  }

  return \@titlist;
}

1;
