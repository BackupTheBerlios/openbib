#!/usr/bin/perl

#####################################################################
#
#  alt_remote.pl
#
#  Holen via http und konvertieren in das Meta-Format
#
#  Dieses File ist (C) 2003-2006 Oliver Flimm <flimm@openbib.org>
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

use DBI;
use OpenBib::Config;

my $config = new OpenBib::Config();

my $rootdir       = $config->{'autoconv_dir'};
my $pooldir       = $rootdir."/pools";
my $konvdir       = $config->{'conv_dir'};
my $confdir       = $config->{'base_dir'}."/conf";
my $wgetexe       = "/usr/bin/wget -v ";
my $alephmab2metaexe   = "$konvdir/alephmab2meta.pl";

my $pool          = $ARGV[0];

my $dboptions_ref = $config->get_dboptions($pool);

print YAML::Dump($dboptions_ref);

my $url        = "$dboptions_ref->{protocol}://$dboptions_ref->{host}/$dboptions_ref->{filename}";
#my $url        = "$dboptions_ref->{protocol}://$dboptions_ref->{host}/$dboptions_ref->{remotepath}/";
my $ftpauthstring="";
if ($dboptions_ref->{protocol} eq "ftp" && $dboptions_ref->{remoteuser} ne "" && $dboptions_ref->{remotepasswd} ne ""){
    $ftpauthstring=" --ftp-user=$dboptions_ref->{remoteuser} --ftp-password=$dboptions_ref->{remotepasswd}";
}

print "### $pool: Datenabzug via http von $url\n";
system("cd $pooldir/$pool ; rm unload.* ; rm tmp.*");
system("$wgetexe $ftpauthstring -N -P $pooldir/$pool/ $url ");

opendir(DIR, "$pooldir/$pool/");
@FILES= readdir(DIR); 

my $lastdate = 0;
foreach my $file(@FILES){
    if ($file=~m/export_mab_HBZ\d\d.K1.F.(\d\d\d\d\d\d\d\d).\d+\.zip/){
        my $thisdate = $1;
        if ($thisdate > $lastdate){
            $lastdate = $thisdate;
        }
    }
}

print "Letztes Datum: $lastdate\n";

foreach my $file(@FILES){
    if ($file=~m/export_mab_HBZ01.K1.F.$lastdate.\d+\.zip/){
        system("unzip -v -p $pooldir/$pool/$file > $pooldir/$pool/tmp.TIT");
    }
    if ($file=~m/export_mab_HBZ10.K1.F.$lastdate.\d+\.zip/){
        system("unzip -v -p $pooldir/$pool/$file > $pooldir/$pool/tmp.PER");
    }
    if ($file=~m/export_mab_HBZ11.K1.F.$lastdate.\d+\.zip/){
        system("unzip -v -p $pooldir/$pool/$file > $pooldir/$pool/tmp.KOE");
    }
    if ($file=~m/export_mab_HBZ12.K1.F.$lastdate.\d+\.zip/){
        system("unzip -v -p $pooldir/$pool/$file > $pooldir/$pool/tmp.SWD");
    }
    if ($file=~m/export_mab_HBZ60.K1.F.$lastdate.\d+\.zip/){
        system("unzip -v -p $pooldir/$pool/$file > $pooldir/$pool/tmp.MEX");
    }
}

system("cd $pooldir/$pool; $alephmab2metaexe");
system("cd $pooldir/$pool; gzip unload.*");

