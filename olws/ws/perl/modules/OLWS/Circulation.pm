#####################################################################
#
#  Open Library WebServices
#
#  OLWS::Circulation
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

package OLWS::Circulation;

use strict;
use warnings;

use Log::Log4perl qw(get_logger :levels);

use OLWS::Config;
use Data::Dumper;

# Liste der moeglichen Backend-Module
use OLWS::Sisis::Circulation;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace

use vars qw(%config);

*config=\%OLWS::Config::config;

# Verlaengerungen
sub get_renewals {
    my ($self,$arg_ref) = @_;

    my $backend="OLWS::$config{backend}::Circulation";

    return $backend->new($arg_ref->{database})->get_renewals($arg_ref);
}

# Bestellungen
sub get_orders {
    my ($self,$arg_ref) = @_;

    my $backend="OLWS::$config{backend}::Circulation";

    return $backend->new($arg_ref->{database})->get_orders($arg_ref);
}

# Vormerkungen
sub get_reservations {
    my ($self,$arg_ref) = @_;

    my $backend="OLWS::$config{backend}::Circulation";

    return $backend->new($arg_ref->{database})->get_reservations($arg_ref);
}

# Mahnungen
sub get_reminders {
    my ($self,$arg_ref) = @_;

    my $backend="OLWS::$config{backend}::Circulation";

    return $backend->new($arg_ref->{database})->get_reminders($arg_ref);
}

# Aktive Ausleihen
sub get_borrows {
    my ($self,$arg_ref) = @_;

    my $backend="OLWS::$config{backend}::Circulation";

    return $backend->new($arg_ref->{database})->get_borrows($arg_ref);
}

# Aktive Ausleihen
sub get_idn_of_borrows {
    my ($self,$arg_ref) = @_;

    my $backend="OLWS::$config{backend}::Circulation";

    return $backend->new($arg_ref->{database})->get_idn_of_borrows($arg_ref);
}

# Titel vormerken
sub make_reservation {
    my ($self,$arg_ref) = @_;

    my $backend="OLWS::$config{backend}::Circulation";

    return $backend->make_reservation($arg_ref);
}

1;
