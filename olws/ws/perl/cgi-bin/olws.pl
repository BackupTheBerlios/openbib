#!/usr/bin/perl

#####################################################################
#
#  Open Library WebServices
#
#  olws.pl
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

use SOAP::Transport::HTTP;
use Log::Log4perl;

Log::Log4perl->init_once($OLWS::Config::config{log4perl_path});

SOAP::Transport::HTTP::CGI
  -> dispatch_with({
                     'urn:/Authentication' => 'OLWS::Sisis::Authentication',
                     'urn:/Circulation'    => 'OLWS::Sisis::Circulation',
                     'urn:/Media'          => 'OLWS::Sisis::Media',
                     'urn:/MediaStatus'    => 'OLWS::Sisis::MediaStatus',
                   })
  -> handle;
