#####################################################################
#
#  Open Library WebServices
#
#  OLWS::Media
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

package OLWS::Media;

use strict;
use warnings;

use OLWS::Config;

# Liste der moeglichen Backend-Module
use OLWS::Sisis::Media;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace

use vars qw(%config);

*config=\%OLWS::Config::config;

sub get_native_title_by_katkey {
    my ($self,$arg_ref) = @_;

    my $backend="OLWS::$config{backend}::Media";
    return $backend->get_native_title_by_katkey($arg_ref);
}

sub get_raw_tit_by_katkey {
    my ($self,$arg_ref) = @_;

    my $backend="OLWS::$config{backend}::Media";
    return $backend->get_raw_title_by_katkey($arg_ref);
}

sub get_raw_aut_by_katkey {
    my ($self,$arg_ref) = @_;

    my $backend="OLWS::$config{backend}::Media";
    return $backend->get_raw_aut_by_katkey($arg_ref);
}

sub get_raw_kor_by_katkey {
    my ($self,$arg_ref) = @_;

    my $backend="OLWS::$config{backend}::Media";
    return $backend->get_raw_kor_by_katkey($arg_ref);
}

sub get_raw_swt_by_katkey {
    my ($self,$arg_ref) = @_;

    my $backend="OLWS::$config{backend}::Media";
    return $backend->get_raw_swt_by_katkey($arg_ref);
}

sub get_raw_not_by_katkey {
    my ($self,$arg_ref) = @_;

    my $backend="OLWS::$config{backend}::Media";
    return $backend->get_raw_not_by_katkey($arg_ref);
}

sub get_title_katkeys_by_date {
    my ($self,$arg_ref) = @_;

    my $backend="OLWS::$config{backend}::Media";
    return $backend->get_title_katkeys_by_date($arg_ref);
}

1;
