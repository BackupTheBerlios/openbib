#####################################################################
#
#  Open Library WebServices
#
#  OLWS::Sisis::Statistics
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

package OLWS::Sisis::Statistics;

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

sub get_current_borrows {
    my ($class, $args_ref) = @_;

    my $username = $args_ref->{username};
    my $password = $args_ref->{password};
    my $database = $args_ref->{database};

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
  #####################################################################
  # Verbindung zur SQL-Datenbank herstellen
  
  my $dbh=DBI->connect("DBI:$config{dbimodule}:dbname=$database;server=$config{dbserver};host=$config{dbhost};port=$config{dbport}", $config{dbuser}, $config{dbpasswd}) or $logger->error_die($DBI::errstr);

my $request=$dbh->prepare("select b.d01bnr as id, b.d01katkey as katkey, d.isbn as isbn from $database.sisis.d01buch as b, $database.sisis.titel_dupdaten as d where b.d01status = 4 and b.d01bg in (1,2,3,4,5,6,7,17,18) and b.d01katkey=d.katkey");
$request->execute() or $logger->error_die($DBI::errstr);

  my $borrows_ref=();
  while (my $result=$request->fetchrow_hashref){
   my $id     = $result->{id};
   my $katkey = $result->{katkey};
   my $isbn   = $result->{isbn} || '';

   $id=~s/#.$//;
   $isbn=~s/ //g;
   $isbn=~s/-//g;
   $isbn=~s/([A-Z])/\l$1/g;

   push @$borrows_ref, {
     id       => $id,
     isbn     => $isbn,
     katkey   => $katkey,
   };
  }

  return $borrows_ref;
}
1;
