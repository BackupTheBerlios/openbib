#####################################################################
#
#  Open Library WebServices
#
#  OLWS::Dispatch
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

package OLWS::Dispatch;

use strict;
use warnings;

use Log::Log4perl qw(get_logger :levels);

use OLWS::Sisis::Config;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace

use vars qw(%config);

*config=\%OLWS::Sisis::Config::config;


use SOAP::Transport::HTTP;

my $server = SOAP::Transport::HTTP::Apache
  -> dispatch_with({
                     'urn:/Aquisition'     => 'OLWS::Sisis::Aquisition',
                     'urn:/Authentication' => 'OLWS::Sisis::Authentication',
                     'urn:/Circulation'    => 'OLWS::Sisis::Circulation',
                     'urn:/Media'          => 'OLWS::Sisis::Media',
                     'urn:/MediaStatus'    => 'OLWS::Sisis::MediaStatus',
                   });

sub handler { 
   my $r=$_[0];
   
   # Log4perl logger erzeugen

   my $logger = get_logger();

   $logger->info("Request from: ".$r->get_remote_host);

   $server->handler(@_); 
}

1;

