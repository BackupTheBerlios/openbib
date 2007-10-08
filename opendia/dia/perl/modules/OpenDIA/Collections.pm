#####################################################################
#
#  OpenDIA::Collections
#
#  Dieses File ist (C) 2001-2004 Oliver Flimm <flimm@openbib.org>
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

package OpenDIA::Collections;

use strict;
use warnings;
no warnings 'redefine';

use Apache::Constants qw(:common);
use DBI;
use File::Find::Rule;
use Log::Log4perl qw(get_logger :levels);

use OpenDIA::Common::Util;
use OpenDIA::Config;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace
use vars qw(%config);

*config=\%OpenDIA::Config::config;

sub get_collections {
    my $collectionbasedir=$config{collection_base_dir};

    # Log4perl logger erzeugen
    my $logger = get_logger();

    $logger->info("Collectionbasedir: $collectionbasedir");

    my @collections=();
    my $direntry;

    opendir(COLLDIR,"$collectionbasedir");

    while (defined($direntry=readdir(COLLDIR))) {
        my $filename="$collectionbasedir/$direntry";
    
        if ( -d $filename ) {
            push @collections, grep { /^\w+/ } $direntry;
        }
    }

    closedir(COLLDIR);
    return @collections;
}

sub collection_is_valid {
    my ($collection)=@_;

    my @collections=get_collections();
    my $valid=0;

    foreach my $col (@collections) {
        if ($col eq $collection) {
            $valid=1;
        }
    }

    return $valid;
}

sub get_items {
    my ($collection)=@_;

    my $collectionbasedir=$config{collection_base_dir}."/$collection/";
    my $rule=File::Find::Rule->new;

    my @items = File::Find::Rule->relative->directory->name( qr/^\d+$/ )->in( $collectionbasedir );
  
    return sort {$a <=> $b} @items;
}

sub analyze_item {
    my ($collection,$item)=@_;

    my $itembasedir=$config{collection_base_dir}."/$collection/$item";
    my $rule=File::Find::Rule->new;

    my @items = grep { !/thumb/ } grep { !/web/ } File::Find::Rule->relative->maxdepth(1)->file()->name( '*.jpg' )->in( $itembasedir );

    push @items, File::Find::Rule->relative->maxdepth(1)->file()->name( '*.png' )->in( $itembasedir );
    push @items, File::Find::Rule->relative->maxdepth(1)->file()->name( '*.tif' )->in( $itembasedir );

    my @chapters = grep { /^ch/ } File::Find::Rule->relative->maxdepth(1)->directory()->in( $itembasedir );

    my @itemlist=();

    foreach my $image (@items) {
        my ($front,$ext)=$image=~m/^(.+?)\.(...)$/;

        my $thumb="";
        my $web="";

        if ( -e "$itembasedir/$front"."_thumb.jpg" ) {
            $thumb="$front"."_thumb.jpg";
        }

        if ( -e "$itembasedir/$front"."_web.jpg" ) {
            $web="$front"."_web.jpg";
        }

        my $metainfolist=analyze_meta($collection,$item,'',$image);
    
        my $singleimage={
            type  => 'image',
            name  => $image,
            thumb => $thumb,
            web   => $web,
            meta  => $metainfolist,
        };

        push @itemlist, $singleimage;
    }

    foreach my $chapter (@chapters) {
        my ($count)=$chapter=~m/^ch\-(.+?)$/;

        my @iteminfo=analyze_item($collection,"$item/$chapter");

        my $singlechapter={
            type    => 'chapter',
            name    => $chapter,
            count   => $count,
            content => \@iteminfo,
        };

        push @itemlist, $singlechapter;
    }


    my @sorteditemlist=sort by_name @itemlist;
  
    return @sorteditemlist;
}

sub analyze_meta {
    my ($collection,$item,$subpath,$image)=@_;

    my $logger = get_logger();

    my $itembasedir=$config{collection_base_dir}."/$collection";

    if ($item) {
        $itembasedir=$itembasedir."/$item";
    }
  
    if ($subpath) {
        $itembasedir=$itembasedir."/$subpath";
    }

    my $rule=File::Find::Rule->new;
    my @metainfos = ();

    if ($image) {
        @metainfos = grep { /$image/ } File::Find::Rule->relative->maxdepth(1)->file()->name( '*.dsc' )->in( $itembasedir );
    }
    else {
        @metainfos = grep { /^meta/ } File::Find::Rule->relative->maxdepth(1)->file()->name( '*.dsc' )->in( $itembasedir );
    }
  
    my %metainfolist=();

    foreach my $metainfo (@metainfos) {
        my ($metacat)=$metainfo=~m/^.+?_(.+?)\.dsc$/;

        #    $metacat=~s/\./\_/g;

        my $content="";
        open (META,"$itembasedir/$metainfo");
        while (<META>) {
            $content=$content.$_;
        }
        close (META);

        $metainfolist{"$metacat"}=$content;
    }
    return \%metainfolist;
}

sub by_name {
    my %line1=%$a;
    my %line2=%$b;

    $line1{name} cmp $line2{name};
}

sub update_item {
    my ($collection,$item)=@_;

    my $logger = get_logger();

    my $collectionbasedir=$config{collection_base_dir};
  
    # Verbindung zur SQL-Datenbank herstellen
    my $metadbh
        = DBI->connect("DBI:$config{dbimodule}:dbname=$config{metadbname};host=$config{metadbhost};port=$config{metadbport}", $config{metadbuser}, $config{metadbpasswd})
            or $logger->error_die($DBI::errstr);
  
    my $request=$metadbh->prepare("delete from meta where collection=? and item=?");

    $request->execute($collection,$item);

    my $rule=File::Find::Rule->new;
    my @files = sort File::Find::Rule->relative->file()->in( "$collectionbasedir/$collection/$item" );

    foreach my $file (@files) {
        $logger->info("File: $file\n");
    
        my ($metapath,$metaelement,$category,$ext,$ismeta)=("","","","","");
    
        if ($file=~/.*\.dsc$/) {
            # Metadaten
            if ($file=~/^(.*)\/(.+?)_(.+?)\.dsc$/) {
                ($metapath,$metaelement,$category)=$file=~m/^(.*)\/(.+?)_(.+?)\.dsc$/;
            }
            else {
                $metapath="";
                ($metaelement,$category)=$file=~m/^(.+?)_(.+?)\.dsc$/;
            }
            $ismeta=1;
        }
        elsif ($file=~/\.tif$/ || $file =~/\.jpg$/ || $file =~/\.png$/) {
            # Originaldaten
            if ($file=~/^(.*)\/(.+?)_(.+?)\.dsc$/) {
                ($metapath,$metaelement)=$file=~m/^(.*)\/(.+?\....)$/;
            }
            else {
                $metapath="";
                ($metaelement)=$file=~m/^(.+?\....)$/;
            }
            next if ($metaelement=~m/_web\..+/);
            next if ($metaelement=~m/_thumb\..+/);
        }
    
        my @path=split("\/",$metapath);
    
        my $sub        = "";
        my $sub1       = "";
        my $sub2       = "";
        my $image      = "";
        my $type       = "";
        my $metascheme = "";
    
        if (defined($path[0])) {
            $collection=$path[0];
        }
    
        if (defined($path[1])) {
            $item=$path[1];
        }
    
        if (defined($path[2])) {
            $sub=$path[2];
        }
    
        if (defined($path[3])) {
            $sub1=$path[3];
        }
    
        if (defined($path[4])) {
            $sub2=$path[4];
        }
    
        if ($metaelement eq "meta") {
            $type="orgunit";
            $image="";
        }
        else {
            $type="image";
            $image=$metaelement;
        }
    
        if ($category=~m/^DC/) {
            $metascheme="dc";
        }
        elsif ($category=~m/^M\d/) {
            $metascheme="emab";
        }

        $logger->info("PATH: $metapath - CAT: $category - C: $collection I: $item S0: $sub S1: $sub1 S2: $sub2 EL: $metaelement - ALL: $file SCH: $metascheme TY: $type");

        if ($ismeta) {
            $logger->info("Opening Meta: $collectionbasedir/$collection/$item/$file");
            my $content="";
            open (META,"$collectionbasedir/$collection/$item/$file");
            while (<META>) {
                $content=$content.$_;
            }
            close (META);

            # Wenn multipler Inhalt
            if ($content=~m/. - /) {
                my @multcontent=split(". - ",$content);
	
                foreach my $singlecontent (@multcontent) {
                    $request=$metadbh->prepare("insert into meta values (NULL,?,?,?,?,?,?,?,?,?,?,?)");
                    $request->execute($collection,$item,$sub,$sub1,$sub2,$image,$type,$metascheme,$category,$singlecontent,$singlecontent);
                }
            }
            # Wenn einfacher Inhalt
            else {
                $request=$metadbh->prepare("insert into meta values (NULL,?,?,?,?,?,?,?,?,?,?,?)");
                $request->execute($collection,$item,$sub,$sub1,$sub2,$image,$type,$metascheme,$category,$content,$content);
            }
        }
        # Wenn es Bilder etc sind und keine Meta-Daten
        else {
            $logger->info("Opening Item: $collectionbasedir/$collection/$item/$file");

            $request=$metadbh->prepare("insert into meta values (NULL,?,?,?,?,?,?,?,?,?,?,?)");
            $request->execute($collection,$item,$sub,$sub1,$sub2,$image,$type,$metascheme,$category,'','');

        }
    }
  
    $request->finish();
    $metadbh->disconnect();

    return;
}

sub update_collection {
    my ($collection)=@_;

    my $item="";
    my $logger = get_logger();

    my $collectionbasedir=$config{collection_base_dir};
  
    # Verbindung zur SQL-Datenbank herstellen
    my $metadbh
        = DBI->connect("DBI:$config{dbimodule}:dbname=$config{metadbname};host=$config{metadbhost};port=$config{metadbport}", $config{metadbuser}, $config{metadbpasswd})
            or $logger->error_die($DBI::errstr);
  
    my $request=$metadbh->prepare("delete from meta where collection=? and item=''");
    $request->execute($collection);

    my $rule=File::Find::Rule->new;

    my @files = File::Find::Rule->relative->maxdepth(1)->file()->in( "$collectionbasedir/$collection" );

    foreach my $file (@files) {
        $logger->info("File: $file\n");
    
        my ($metapath,$metaelement,$category,$ext,$ismeta)=("","","","","");
    
        if ($file=~/.*\.dsc$/) {
            # Metadaten
            if ($file=~/^(.*)\/(.+?)_(.+?)\.dsc$/) {
                ($metapath,$metaelement,$category)=$file=~m/^(.*)\/(.+?)_(.+?)\.dsc$/;
            }
            else {
                $metapath="";
                ($metaelement,$category)=$file=~m/^(.+?)_(.+?)\.dsc$/;
            }
            $ismeta=1;
        }
        elsif ($file=~/\.tif$/ || $file =~/\.jpg$/ || $file =~/\.png$/) {
            # Originaldaten
            if ($file=~/^(.*)\/(.+?)_(.+?)\.dsc$/) {
                ($metapath,$metaelement)=$file=~m/^(.*)\/(.+?\....)$/;
            }
            else {
                $metapath="";
                ($metaelement)=$file=~m/^(.+?\....)$/;
            }
            next if ($metaelement=~m/_web\..+/);
            next if ($metaelement=~m/_thumb\..+/);
        }
    
        my @path=split("\/",$metapath);
    
        my $sub        = "";
        my $sub1       = "";
        my $sub2       = "";
        my $image      = "";
        my $type       = "";
        my $metascheme = "";
    
        if (defined($path[0])) {
            $collection=$path[0];
        }
    
        if (defined($path[1])) {
            $item=$path[1];
        }
    
        if (defined($path[2])) {
            $sub=$path[2];
        }
    
        if (defined($path[3])) {
            $sub1=$path[3];
        }
    
        if (defined($path[4])) {
            $sub2=$path[4];
        }
    
        if ($metaelement eq "meta") {
            $type="orgunit";
            $image="";
        }
        else {
            $type="image";
            $image=$metaelement;
        }
    
        if ($category=~m/^DC/) {
            $metascheme="dc";
        }
        elsif ($category=~m/^M\d/) {
            $metascheme="emab";
        }

        $logger->info("PATH: $metapath - CAT: $category - C: $collection I: $item S0: $sub S1: $sub1 S2: $sub2 EL: $metaelement - ALL: $file SCH: $metascheme TY: $type");

        if ($ismeta) {

            $logger->info("Opening Meta: $collectionbasedir/$collection/$file");
            my $content="";
            open (META,"$collectionbasedir/$collection/$file");
            while (<META>) {
                $content=$content.$_;
            }
            close (META);

            # Wenn multipler Inhalt
            if ($content=~m/. - /) {
                my @multcontent=split(". - ",$content);
	
                foreach my $singlecontent (@multcontent) {
                    $request=$metadbh->prepare("insert into meta values (NULL,?,?,?,?,?,?,?,?,?,?,?)");
                    $request->execute($collection,$item,$sub,$sub1,$sub2,$image,$type,$metascheme,$category,$singlecontent,$singlecontent);
                }
            }
            # Wenn einfacher Inhalt
            else {
                $request=$metadbh->prepare("insert into meta values (NULL,?,?,?,?,?,?,?,?,?,?,?)");
                $request->execute($collection,$item,$sub,$sub1,$sub2,$image,$type,$metascheme,$category,$content,$content);
            }
        }
        # Wenn es Bilder etc sind und keine Meta-Daten
        else {
            $logger->info("Opening Item: $collectionbasedir/$collection/$file");

            $request=$metadbh->prepare("insert into meta values (NULL,?,?,?,?,?,?,?,?,?,?,?)");
            $request->execute($collection,$item,$sub,$sub1,$sub2,OpenDIA::Common::Util::conv2web($image),$type,$metascheme,$category,'','');

        }
    }
  
    $request->finish();
    $metadbh->disconnect();

    return;
}
 
1;
