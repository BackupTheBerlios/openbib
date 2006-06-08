####################################################################
#
#  OpenBib::Connector::OLWS.pm
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

#####################################################################
# Einladen der benoetigten Perl-Module 
#####################################################################

package OpenBib::Connector::OLWS;

use Apache::Constants qw(:common);

use strict;
use warnings;
no warnings 'redefine';

use Apache::Reload;
use Apache::Request();          # CGI-Handling (or require)
use Log::Log4perl qw(get_logger :levels);
use SOAP::Transport::HTTP;
use OpenBib::Config;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace
use vars qw(%config);
*config=\%OpenBib::Config::config;

my $server = SOAP::Transport::HTTP::Apache
    -> dispatch_with({
        'urn:/Search'         => 'OpenBib::Connector::OLWS::Search',
    });

sub handler {
    my $r=$_[0];

    # Log4perl logger erzeugen

    my $logger = get_logger();

    $logger->info("Request from: ".$r->get_remote_host);

    $server->handler(@_);
}

1;