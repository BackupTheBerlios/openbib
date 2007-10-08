#####################################################################
#
#  OpenDIA::Editor
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

package OpenDIA::Editor;

use strict;
use warnings;
no warnings 'redefine';

use Apache::Constants qw(:common);
use Apache::Request ();
use Image::Magick;
use Log::Log4perl qw(get_logger :levels);
use SOAP::Lite;
use Template;

use OpenDIA::Collections;
use OpenDIA::Common::Util;
use OpenDIA::Config;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace
use vars qw(%config);

*config=\%OpenDIA::Config::config;

sub handler {
    my $r=shift;
  
    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $query=Apache::Request->new($r);

    my $collection = $query->param('collection') || '';
    my $action     = $query->param('action')     || '';
    my $item       = $query->param('item')       || 0;
    my $sub        = $query->param('sub')        || 0;
    my $sub1       = $query->param('sub1')       || 0;
    my $sub2       = $query->param('sub2')       || 0;
    my $image      = $query->param('image')      || '';
    my $meta       = $query->param('meta')       || 'dc';

    # Metadaten DC
    my $dctitle        = $query->param('DC.Title')        || '';
    my $dccreator      = $query->param('DC.Creator')      || '';
    my $dcsubject      = $query->param('DC.Subject')      || '';
    my $dcdescription  = $query->param('DC.Description')  || '';
    my $dcpublisher    = $query->param('DC.Publisher')    || '';
    my $dccontributors = $query->param('DC.Contributors') || '';
    my $dcdate         = $query->param('DC.Date')         || '';
    my $dctype         = $query->param('DC.Type')         || '';
    my $dcformat       = $query->param('DC.Format')       || '';
    my $dcidentifier   = $query->param('DC.Identifier')   || '';
    my $dcsource       = $query->param('DC.Source')       || '';
    my $dclanguage     = $query->param('DC.Language')     || '';
    my $dcrelation     = $query->param('DC.Relation')     || '';
    my $dccoverage     = $query->param('DC.Coverage')     || '';
    my $dcrights       = $query->param('DC.Rights')       || '';

    if (!$collection) {
        my @collections=OpenDIA::Collections::get_collections();

        # TT-Data erzeugen
        my $ttdata={
            collections  => \@collections,
            config       => \%config,
        };
    
        OpenDIA::Common::Util::print_page($config{tt_editor_showallcolls_tname}, $ttdata, $r);
  
        return OK;
    
    }
    else {
        if (!OpenDIA::Collections::collection_is_valid($collection)) {
            # TT-Data erzeugen
            my $ttdata={
                errmsg       => "Digitalisat-Serie nicht g&uuml;ltig",
                config       => \%config,
            };

            OpenDIA::Common::Util::print_page($config{tt_error_tname}, $ttdata, $r);
      
            return OK;
        }
    
    }
  
    if ($action eq "choosecollection") {
        my @items=OpenDIA::Collections::get_items($collection);
    
        # TT-Data erzeugen
        my $ttdata={
            items      => \@items,
            collection => $collection,
            config     => \%config,
        };

        OpenDIA::Common::Util::print_page($config{tt_editor_showsinglecoll_tname}, $ttdata, $r);    
    
        return OK;
    }
    elsif ($action eq "showitem") {
        my @iteminfo=OpenDIA::Collections::analyze_item($collection,$item);
        #    my @items=OpenDIA::Collections::get_items($collection,$item);
    
        # TT-Data erzeugen
        my $ttdata={
            item       => $item,
            iteminfo   => \@iteminfo,
            collection => $collection,
            config     => \%config,
        };
    
        OpenDIA::Common::Util::print_page($config{tt_editor_showsingleitem_tname}, $ttdata, $r);    
        return OK;
    
    }
    elsif ($action eq "genthumbs") {
        OpenDIA::Common::Util::genThumbFromFS($collection,$item) if ($collection && $item);

        $r->internal_redirect("http://$config{servername}$config{editor_loc}?action=showitem;collection=$collection;item=$item");
    
        return OK;
    
    }
    elsif ($action eq "genweb") {
        OpenDIA::Common::Util::genWebFromFS($collection,$item) if ($collection && $item);

        $r->internal_redirect("http://$config{servername}$config{editor_loc}?action=showitem;collection=$collection;item=$item");
    
        return OK;
    
    }
    elsif ($action eq "editmeta") {
        my $subpath="";
        if ($sub) {
            $subpath=$subpath."/".$sub;
        }
        if ($sub1) {
            $subpath=$subpath."/".$sub1;
        }
        if ($sub2) {
            $subpath=$subpath."/".$sub2;
        }

        my @iteminfo=OpenDIA::Collections::analyze_item($collection,$item.$subpath);
        my $metainfo=OpenDIA::Collections::analyze_meta($collection,$item,$subpath,$image);
        

        my $ttdata={
            collection => $collection,
            item       => $item,
            sub        => $sub,
            sub1       => $sub1,
            sub2       => $sub2,
            image      => $image,
            meta       => $meta,
            iteminfo   => \@iteminfo,
            metainfo   => $metainfo,
            config     => \%config,
        };
    
        OpenDIA::Common::Util::print_page($config{tt_editor_editmeta_tname}, $ttdata, $r);    

        return OK;
    }
    elsif ($action eq "savemeta") {
        my $subpath=$config{collection_base_dir}."/$collection";
    
        if ($item) {
            $subpath=$subpath."/".$item;
        }
        if ($sub) {
            $subpath=$subpath."/".$sub;
        }
        if ($sub1) {
            $subpath=$subpath."/".$sub1;
        }
        if ($sub2) {
            $subpath=$subpath."/".$sub2;
        }

        $image="meta" unless ($image);

        $subpath=$subpath."/".$image;

        foreach my $metaschemeref (@{$config{"metascheme"}{"$collection"}{"$meta"}}) {
            my %metascheme=%$metaschemeref;

            # Wenn der Parameter besetzt ist, dann abspeichern
            if ($query->param($metascheme{"cat"})) {
                open(META,">$subpath"."_".$metascheme{"cat"}.".dsc");
                print META $query->param($metascheme{"cat"});
                close(META);
            }
            # ansonsten loeschen
            else {
               unlink "$subpath"."_".$metascheme{"cat"}.".dsc";
            }
        }

        if ($item) {
            $r->internal_redirect("http://$config{servername}$config{editor_loc}?action=showitem;collection=$collection;item=$item");
            OpenDIA::Collections::update_item($collection,$item);
        }
        else {
            $r->internal_redirect("http://$config{servername}$config{editor_loc}?action=choosecollection;collection=$collection");
            OpenDIA::Collections::update_collection($collection);
        }

        return OK;

    }
    elsif ($action eq "importpool") {
        # Bestehende Katalogaufnahmen dienen immer nur als Beschreibung
        # fuer das gesamte Digitalisat
        OpenDIA::Common::Util::importPoolData($collection,$item,$meta);

        $r->internal_redirect("http://$config{servername}$config{editor_loc}?action=editmeta;collection=$collection;item=$item;sub=$sub;sub1=$sub1;sub2=$sub2;image=$image;meta=$meta");

        return OK;
    }
    else {
        # TT-Data erzeugen
        my $ttdata={
            errmsg       => "Unerlaubte Aktion",
            config       => \%config,
        };

        OpenDIA::Common::Util::print_page($config{tt_error_tname}, $ttdata, $r);        
        return OK;
    }
}

1;
