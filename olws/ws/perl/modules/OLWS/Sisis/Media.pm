#####################################################################
#
#  Open Library WebServices
#
#  OLWS::Sisis::Media
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

package OLWS::Sisis::Media;

use strict;
use warnings;

use Log::Log4perl qw(get_logger :levels);
use Encode qw/encode decode/;

use DBI;

use OLWS::Sisis::Config;
use OLWS::Sisis::Data;

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

sub get_native_title_by_katkey {
  my ($self, $args_ref) = @_;

  my $katkey   = $args_ref->{katkey};
  my $database = $args_ref->{database};
  
  # Log4perl logger erzeugen

  my $logger = get_logger();
  
  my $title_ref    = OLWS::Sisis::Data::get_titref_by_katkey($self->{sikfstab},$self->{dbh},$database,$katkey);	
  
  return $title_ref;
}

sub get_raw_tit_by_katkey {
  my ($self, $args_ref) = @_;

  my $katkey   = $args_ref->{katkey};
  my $database = $args_ref->{database};

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
  my $title_ref    = OLWS::Sisis::Data::get_raw_titref_by_katkey($self->{sikfstab},$self->{dbh},$database,$katkey);	
  
  return $title_ref;
}


sub get_raw_aut_by_katkey {
  my ($self, $args_ref) = @_;

  my $katkey   = $args_ref->{katkey};
  my $database = $args_ref->{database};

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
  my $aut_ref      = OLWS::Sisis::Data::get_raw_autref_by_katkey($self->{sikfstab},$self->{dbh},$database,$katkey);	
  
  return $aut_ref;
}

sub get_raw_kor_by_katkey {
  my ($self, $args_ref) = @_;

  my $katkey   = $args_ref->{katkey};
  my $database = $args_ref->{database};

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
  my $korref=OLWS::Sisis::Data::get_raw_korref_by_katkey($self->{sikfstab},$self->{dbh},$database,$katkey);	
  
  return $korref;
}

sub get_raw_swt_by_katkey {
  my ($self, $args_ref) = @_;

  my $katkey   = $args_ref->{katkey};
  my $database = $args_ref->{database};

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
  my $swtref=OLWS::Sisis::Data::get_raw_swtref_by_katkey($self->{sikfstab},$self->{dbh},$database,$katkey);	
  
  return $swtref;
}

sub get_raw_not_by_katkey {
  my ($self, $args_ref) = @_;

  my $katkey   = $args_ref->{katkey};
  my $database = $args_ref->{database};

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
  my $notref=OLWS::Sisis::Data::get_raw_notref_by_katkey($self->{sikfstab},$self->{dbh},$database,$katkey);	
  
  return $notref;
}

sub get_title_katkeys_by_date {
  my ($self, $args_ref) = @_;

  my $from_date = $args_ref->{fromdate};
  my $to_date   = $args_ref->{todate};
  my $database  = $args_ref->{database};

  # Log4perl logger erzeugen

  my $logger = get_logger();

  $logger->debug("From: $from_date To: $to_date");  

  my $sql_statement = qq{
  select katkey 

  from $database.sisis.titel_exclude
  };

  my $request=$self->{dbh}->prepare($sql_statement);
  $request->execute();

  my $excluded_katkey_ref=();
  while (my $res_ref=$request->fetchrow_arrayref){
    $excluded_katkey_ref->{$res_ref->[0]} = 1;
  }	

#  $sql_statement = qq{
#  select distinct dup.katkey as katkey 
#
#  from $database.sisis.titel_dupdaten as dup 
#
#  left join $database.sisis.titel_exclude on $database.sisis.titel_exclude.katkey != dup.katkey 
#
#  where (dup.datumaufn >= ? and dup.datumaufn <= ?) 
#    or (dup.datumaend >= ? and dup.datumaend <= ?)
#  };

  $sql_statement = qq{
  select dup.katkey 

  from $database.sisis.titel_dupdaten as dup 

  where (dup.datumaufn >= ? and dup.datumaufn <= ?) 
    or (dup.datumaend >= ? and dup.datumaend <= ?)
  };

  $request=$self->{dbh}->prepare($sql_statement);
  $request->execute($from_date,$to_date,$from_date,$to_date) or $logger->error_die($DBI::errstr);

  my @katkeys=();
  while (my $res_ref=$request->fetchrow_arrayref){
    push @katkeys, $res_ref->[0] if (!defined $excluded_katkey_ref->{$res_ref->[0]});
  }	

  return \@katkeys;
}

sub DESTROY {
    my $self = shift;

    return if (!defined $self->{dbh});

    $self->{dbh}->disconnect();

    return;
}

1;
