#####################################################################
#
#  OpenBib::SearchQuery
#
#  Dieses File ist (C) 2008 Oliver Flimm <flimm@openbib.org>
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

package OpenBib::SearchQuery;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use base qw(Apache::Singleton);

use Apache::Request ();
use DBI;
use Encode 'decode_utf8';
use Log::Log4perl qw(get_logger :levels);
use Storable;
use String::Tokenizer;
use YAML;

use OpenBib::Common::Util;
use OpenBib::Config;
use OpenBib::Database::DBI;
use OpenBib::VirtualSearch::Util;

sub _new_instance {
    my ($class) = @_;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $self = {
        _searchquery => {
            fs   => {
                norm => '',
                val  => '',
                bool => '',
            },
            verf   => {
                norm => '',
                val  => '',
                bool => '',
            },
            hst   => {
                norm => '',
                val  => '',
                bool => '',
            },
            hststring  => {
                norm => '',
                val  => '',
                bool => '',
            },
            gtquelle   => {
                norm => '',
                val  => '',
                bool => '',
            },
            swt   => {
                norm => '',
                val  => '',
                bool => '',
            },
            kor   => {
                norm => '',
                val  => '',
                bool => '',
            },
            sign   => {
                norm => '',
                val  => '',
                bool => '',
            },
            inhalt   => {
                norm => '',
                val  => '',
                bool => '',
            },
            isbn   => {
                norm => '',
                val  => '',
                bool => '',
            },
            issn   => {
                norm => '',
                val  => '',
                bool => '',
            },
            mart   => {
                norm => '',
                val  => '',
                bool => '',
            },
            notation   => {
                norm => '',
                val  => '',
                bool => '',
            },
            ejahr   => {
                norm => '',
                val  => '',
                bool => '',
            },
        },
    };

    bless ($self, $class);

    return $self;
}

sub set_from_apache_request {
    my ($self,$r)=@_;
    
    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $query = Apache::Request->instance($r);

    # Wandlungstabelle Erscheinungsjahroperator
    my $ejahrop_ref={
        'eq' => '=',
        'gt' => '>',
        'lt' => '<',
    };

    my ($fs, $verf, $hst, $hststring, $gtquelle, $swt, $kor, $sign, $inhalt, $isbn, $issn, $mart,$notation,$ejahr,$ejahrop);

    my ($fsnorm, $verfnorm, $hstnorm, $hststringnorm, $gtquellenorm, $swtnorm, $kornorm, $signnorm, $inhaltnorm, $isbnnorm, $issnnorm, $martnorm,$notationnorm,$ejahrnorm);
    
    $fs        = $fsnorm        = decode_utf8($query->param('fs'))            || $query->param('fs')      || '';
    $verf      = $verfnorm      = decode_utf8($query->param('verf'))          || $query->param('verf')    || '';
    $hst       = $hstnorm       = decode_utf8($query->param('hst'))           || $query->param('hst')     || '';
    $hststring = $hststringnorm = decode_utf8($query->param('hststring'))     || $query->param('hststrin')|| '';
    $gtquelle  = $gtquellenorm  = decode_utf8($query->param('gtquelle'))      || $query->param('qtquelle')|| '';
    $swt       = $swtnorm       = decode_utf8($query->param('swt'))           || $query->param('swt')     || '';
    $kor       = $kornorm       = decode_utf8($query->param('kor'))           || $query->param('kor')     || '';
    $sign      = $signnorm      = decode_utf8($query->param('sign'))          || $query->param('sign')    || '';
    $inhalt    = $inhaltnorm    = decode_utf8($query->param('inhalt'))        || $query->param('inhalt')  || '';
    $isbn      = $isbnnorm      = decode_utf8($query->param('isbn'))          || $query->param('isbn')    || '';
    $issn      = $issnnorm      = decode_utf8($query->param('issn'))          || $query->param('issn')    || '';
    $mart      = $martnorm      = decode_utf8($query->param('mart'))          || $query->param('mart')    || '';
    $notation  = $notationnorm  = decode_utf8($query->param('notation'))      || $query->param('notation')|| '';
    $ejahr     = $ejahrnorm     = decode_utf8($query->param('ejahr'))         || $query->param('ejahr')   || '';
    $ejahrop   =                  decode_utf8($query->param('ejahrop'))       || $query->param('ejahrop') || 'eq';

    my $autoplus      = $query->param('autoplus')      || '';
    my $verfindex     = $query->param('verfindex')     || '';
    my $korindex      = $query->param('korindex')      || '';
    my $swtindex      = $query->param('swtindex')      || '';
    my $notindex      = $query->param('notindex')      || '';

    #####################################################################
    ## boolX: Verknuepfung der Eingabefelder (leere Felder werden ignoriert)
    ##        AND  - Und-Verknuepfung
    ##        OR   - Oder-Verknuepfung
    ##        NOT  - Und Nicht-Verknuepfung
    my $boolverf      = ($query->param('boolverf'))     ?$query->param('boolverf')
        :"AND";
    my $boolhst       = ($query->param('boolhst'))      ?$query->param('boolhst')
        :"AND";
    my $boolswt       = ($query->param('boolswt'))      ?$query->param('boolswt')
        :"AND";
    my $boolkor       = ($query->param('boolkor'))      ?$query->param('boolkor')
        :"AND";
    my $boolnotation  = ($query->param('boolnotation')) ?$query->param('boolnotation')
        :"AND";
    my $boolisbn      = ($query->param('boolisbn'))     ?$query->param('boolisbn')
        :"AND";
    my $boolissn      = ($query->param('boolissn'))     ?$query->param('boolissn')
        :"AND";
    my $boolsign      = ($query->param('boolsign'))     ?$query->param('boolsign')
        :"AND";
    my $boolinhalt    = ($query->param('boolinhalt'))   ?$query->param('boolinhalt')
        :"AND";
    my $boolejahr     = ($query->param('boolejahr'))    ?$query->param('boolejahr')
        :"AND" ;
    my $boolfs        = ($query->param('boolfs'))       ?$query->param('boolfs')
        :"AND";
    my $boolmart      = ($query->param('boolmart'))     ?$query->param('boolmart')
        :"AND";
    my $boolhststring = ($query->param('boolhststring'))?$query->param('boolhststring')
        :"AND";
    my $boolgtquelle  = ($query->param('boolgtquelle')) ?$query->param('boolgtquelle')
        :"AND";

    # Sicherheits-Checks

    my $valid_bools_ref = {
        'AND' => 1,
        'OR'  => 1,
        'NOT' => 1,
    };

    $boolverf      = (exists $valid_bools_ref->{$boolverf     })?$boolverf     :"AND";
    $boolhst       = (exists $valid_bools_ref->{$boolhst      })?$boolhst      :"AND";
    $boolswt       = (exists $valid_bools_ref->{$boolswt      })?$boolswt      :"AND";
    $boolkor       = (exists $valid_bools_ref->{$boolkor      })?$boolkor      :"AND";
    $boolnotation  = (exists $valid_bools_ref->{$boolnotation })?$boolnotation :"AND";
    $boolisbn      = (exists $valid_bools_ref->{$boolisbn     })?$boolisbn     :"AND";
    $boolissn      = (exists $valid_bools_ref->{$boolissn     })?$boolissn     :"AND";
    $boolsign      = (exists $valid_bools_ref->{$boolsign     })?$boolsign     :"AND";
    $boolinhalt    = (exists $valid_bools_ref->{$boolinhalt   })?$boolinhalt   :"AND";
    $boolfs        = (exists $valid_bools_ref->{$boolfs       })?$boolfs       :"AND";
    $boolmart      = (exists $valid_bools_ref->{$boolmart     })?$boolmart     :"AND";
    $boolhststring = (exists $valid_bools_ref->{$boolhststring})?$boolhststring:"AND";
    $boolgtquelle  = (exists $valid_bools_ref->{$boolgtquelle })?$boolgtquelle :"AND";

    $boolejahr    = "AND";

    $boolverf      = "AND NOT" if ($boolverf      eq "NOT");
    $boolhst       = "AND NOT" if ($boolhst       eq "NOT");
    $boolswt       = "AND NOT" if ($boolswt       eq "NOT");
    $boolkor       = "AND NOT" if ($boolkor       eq "NOT");
    $boolnotation  = "AND NOT" if ($boolnotation  eq "NOT");
    $boolisbn      = "AND NOT" if ($boolisbn      eq "NOT");
    $boolissn      = "AND NOT" if ($boolissn      eq "NOT");
    $boolsign      = "AND NOT" if ($boolsign      eq "NOT");
    $boolinhalt    = "AND NOT" if ($boolinhalt    eq "NOT");
    $boolfs        = "AND NOT" if ($boolfs        eq "NOT");
    $boolmart      = "AND NOT" if ($boolmart      eq "NOT");
    $boolhststring = "AND NOT" if ($boolhststring eq "NOT");
    $boolgtquelle  = "AND NOT" if ($boolgtquelle  eq "NOT");

    # Setzen der arithmetischen Ejahrop-Operatoren
    if (exists $ejahrop_ref->{$ejahrop}){
        $ejahrop=$ejahrop_ref->{$ejahrop};
    }
    else {
        $ejahrop="=";
    }
    
    # Filter: ISBN und ISSN

    # Entfernung der Minus-Zeichen bei der ISBN zuerst 13-, dann 10-stellig
    $fsnorm   =~s/(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\S)/$1$2$3$4$5$6$7$8$9$10/g;
    $fsnorm   =~s/(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\S)/$1$2$3$4$5$6$7$8$9$10$11$12$13/g;
    $isbnnorm =~s/(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\S)/$1$2$3$4$5$6$7$8$9$10/g;
    $isbnnorm =~s/(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\S)/$1$2$3$4$5$6$7$8$9$10$11$12$13/g;

    # Entfernung der Minus-Zeichen bei der ISSN
    $fsnorm   =~s/(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*([0-9xX])/$1$2$3$4$5$6$7$8/g;
    $issnnorm =~s/(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*([0-9xX])/$1$2$3$4$5$6$7$8/g;

    my $ejtest;
  
    ($ejtest)=$ejahrnorm=~/.*(\d\d\d\d).*/;
    if (!$ejtest) {
        $ejahrnorm="";              # Nur korrekte Jahresangaben werden verarbeitet
    }                           # alles andere wird ignoriert...
    
    # Filter Rest
    $fsnorm        = OpenBib::Common::Util::grundform({
        content   => $fsnorm,
        searchreq => 1,
    });

    $verfnorm      = OpenBib::Common::Util::grundform({
        content   => $verfnorm,
        searchreq => 1,
    });

    $hstnorm       = OpenBib::Common::Util::grundform({
        content   => $hstnorm,
        searchreq => 1,
    });

    $hststringnorm = OpenBib::Common::Util::grundform({
        category  => "0331", # Exemplarisch fuer die Kategorien, bei denen das erste Stopwort entfernt wird
        content   => $hststringnorm,
        searchreq => 1,
    });

    $gtquellenorm  = OpenBib::Common::Util::grundform({
        content   => $gtquellenorm,
        searchreq => 1,
    });

    $swtnorm       = OpenBib::Common::Util::grundform({
        content   => $swtnorm,
        searchreq => 1,
    });

    $kornorm       = OpenBib::Common::Util::grundform({
        content   => $kornorm,
        searchreq => 1,
    });

    $signnorm      = OpenBib::Common::Util::grundform({
        content   => $signnorm,
        searchreq => 1,
    });

    $inhaltnorm    = OpenBib::Common::Util::grundform({
        content   => $inhaltnorm,
        searchreq => 1,
    });
    
    $isbnnorm      = OpenBib::Common::Util::grundform({
        category  => '0540',
        content   => $isbnnorm,
        searchreq => 1,
    });

    $issnnorm      = OpenBib::Common::Util::grundform({
        category  => '0543',
        content   => $issnnorm,
        searchreq => 1,
    });
    
    $martnorm      = OpenBib::Common::Util::grundform({
        content   => $martnorm,
        searchreq => 1,
    });

    $notationnorm  = OpenBib::Common::Util::grundform({
        content   => $notationnorm,
        searchreq => 1,
    });

    $ejahrnorm      = OpenBib::Common::Util::grundform({
        content   => $ejahrnorm,
        searchreq => 1,
    });
    
    # Umwandlung impliziter ODER-Verknuepfung in UND-Verknuepfung
    if ($autoplus eq "1" && !$verfindex && !$korindex && !$swtindex) {
        $fsnorm       = OpenBib::VirtualSearch::Util::conv2autoplus($fsnorm)   if ($fs);
        $verfnorm     = OpenBib::VirtualSearch::Util::conv2autoplus($verfnorm) if ($verf);
        $hstnorm      = OpenBib::VirtualSearch::Util::conv2autoplus($hstnorm)  if ($hst);
        $kornorm      = OpenBib::VirtualSearch::Util::conv2autoplus($kornorm)  if ($kor);
        $swtnorm      = OpenBib::VirtualSearch::Util::conv2autoplus($swtnorm)  if ($swt);
        $isbnnorm     = OpenBib::VirtualSearch::Util::conv2autoplus($isbnnorm) if ($isbn);
        $issnnorm     = OpenBib::VirtualSearch::Util::conv2autoplus($issnnorm) if ($issn);
        $inhaltnorm   = OpenBib::VirtualSearch::Util::conv2autoplus($inhaltnorm) if ($inhalt);
        $gtquellenorm = OpenBib::VirtualSearch::Util::conv2autoplus($gtquellenorm) if ($gtquelle);
    }

    # (Re-)Initialisierung
    delete $self->{_hits}          if (exists $self->{_hits});
    delete $self->{_searchquery}   if (exists $self->{_searchquery});
    delete $self->{_id}            if (exists $self->{_id});
    
    if ($fs){
      $self->{_searchquery}->{fs}={
			      val   => $fs,
			      norm  => $fsnorm,
			      bool  => '',
			     };
    }

    if ($hst){
      $self->{_searchquery}->{hst}={
			       val   => $hst,
			       norm  => $hstnorm,
			       bool  => $boolhst,
			      };
    }

    if ($hststring){
      $self->{_searchquery}->{hststring}={
				     val   => $hststring,
				     norm  => $hststringnorm,
				     bool  => $boolhststring,
				    };
    }

    if ($gtquelle){
      $self->{_searchquery}->{gtquelle}={
			    val   => $gtquelle,
			    norm  => $gtquellenorm,
			    bool  => $boolgtquelle,
			   };
    }

    if ($inhalt){
      $self->{_searchquery}->{inhalt}={
			    val   => $inhalt,
			    norm  => $inhaltnorm,
			    bool  => $boolinhalt,
			   };
    }

    if ($verf){
      $self->{_searchquery}->{verf}={
			    val   => $verf,
			    norm  => $verfnorm,
			    bool  => $boolverf,
			   };
    }

    if ($swt){
      $self->{_searchquery}->{swt}={
			       val   => $swt,
			       norm  => $swtnorm,
			       bool  => $boolswt,
			      };
    }

    if ($kor){
      $self->{_searchquery}->{kor}={
			       val   => $kor,
			       norm  => $kornorm,
			       bool  => $boolkor,
			      };
    }

    if ($sign){
      $self->{_searchquery}->{sign}={
				val   => $sign,
				norm  => $signnorm,
				bool  => $boolsign,
			       };
    }

    if ($isbn){
      $self->{_searchquery}->{isbn}={
				val   => $isbn,
				norm  => $isbnnorm,
				bool  => $boolisbn,
			     };
    }

    if ($issn){
      $self->{_searchquery}->{issn}={
				val   => $issn,
				norm  => $issnnorm,
				bool  => $boolissn,
			     };
    }

    if ($mart){
      $self->{_searchquery}->{mart}={
				val   => $mart,
				norm  => $martnorm,
				bool  => $boolmart,
			       };
    }

    if ($notation){
      $self->{_searchquery}->{notation}={
				    val   => $notation,
				    norm  => $notationnorm,
				    bool  => $boolnotation,
				   };
    }

    if ($ejahr){
      $self->{_searchquery}->{ejahr}={
			    val   => $ejahr,
			    norm  => $ejahrnorm,
			    bool  => $boolejahr,
			    arg   => $ejahrop,
			   };
    }

    return $self;
}

sub load  {
    my ($self,$arg_ref)=@_;

    # Set defaults
    my $sessionID              = exists $arg_ref->{sessionID}
        ? $arg_ref->{sessionID}           : undef;
    my $queryid                = exists $arg_ref->{queryid}
        ? $arg_ref->{queryid}             : undef;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $config = OpenBib::Config->instance;

    # Verbindung zur SQL-Datenbank herstellen
    my $dbh
        = OpenBib::Database::DBI->connect("DBI:$config->{dbimodule}:dbname=$config->{sessiondbname};host=$config->{sessiondbhost};port=$config->{sessiondbport}", $config->{sessiondbuser}, $config->{sessiondbpasswd})
            or $logger->error_die($DBI::errstr);

    my $idnresult=$dbh->prepare("select query,hits from queries where sessionID = ? and queryid = ?") or $logger->error($DBI::errstr);
    $idnresult->execute($sessionID,$queryid) or $logger->error($DBI::errstr);
    my $res = $idnresult->fetchrow_hashref();

    $self->{_id}          = $queryid;
    $self->{_searchquery} = Storable::thaw(pack "H*", decode_utf8($res->{query}));
    $self->{_hits}        = decode_utf8($res->{'hits'});

    $idnresult->finish();

    return $self;
}


sub get_searchquery {
    my ($self)=@_;

    return $self->{_searchquery};
}

sub get_hits {
    my ($self)=@_;

    return $self->{_hits};
}

sub get_id {
    my ($self)=@_;

    return $self->{_id};
}

sub get_searchfield {
    my ($self,$fieldname)=@_;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    $logger->debug($fieldname);

    $logger->debug(YAML::Dump($self));
    return (exists $self->{_searchquery}->{$fieldname})?$self->{_searchquery}->{$fieldname}:{val => '', norm => '', bool => '', args => ''};
}

sub get_searchterms {
    my ($self) = @_;
    
    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $term_ref = [];

    my @allterms = ();
    foreach my $cat (keys %{$self->{_searchquery}}){
        push @allterms, $self->{_searchquery}->{$cat}->{val} if ($self->{_searchquery}->{$cat}->{val});
    }
    
    my $alltermsstring = join (" ",@allterms);
    $alltermsstring    =~s/[^\p{Alphabetic}0-9 ]//g;

    my $tokenizer = String::Tokenizer->new();
    $tokenizer->tokenize($alltermsstring);

    my $i = $tokenizer->iterator();

    while ($i->hasNextToken()) {
        my $next = $i->nextToken();
        next if (!$next);
        push @$term_ref, $next;
    }

    return $term_ref;
}

sub get_sql_querystring {
    my ($self,$arg_ref) = @_;

    # Set defaults
    my $serien                 = exists $arg_ref->{serien}
        ? $arg_ref->{serien}              : 0;
    my $offset                 = exists $arg_ref->{offset}
        ? $arg_ref->{offset}              : 0;
    my $hitrange               = exists $arg_ref->{hitrange}
        ? $arg_ref->{hitrange}            : 50;
    
    # Aufbau des sqlquerystrings
    my $sqlselect = "";
    my $sqlfrom   = "";
    my $sqlwhere  = "";

    my @sqlwhere = ();
    my @sqlfrom  = ('search');
    my @sqlargs  = ();

    my $notfirstsql=0;
    
    if ($self->{_searchquery}->{fs}->{norm}) {	
        push @sqlwhere, $self->{_searchquery}->{fs}->{bool}." match (verf,hst,kor,swt,notation,sign,inhalt,isbn,issn,ejahrft) against (? IN BOOLEAN MODE)";
        push @sqlargs, $self->{_searchquery}->{fs}->{norm};
    }
   
    if ($self->{_searchquery}->{verf}->{norm}) {	
        push @sqlwhere, $self->{_searchquery}->{verf}->{bool}." match (verf) against (? IN BOOLEAN MODE)";
        push @sqlargs,  $self->{_searchquery}->{verf}->{norm};
    }
  
    if ($self->{_searchquery}->{hst}->{norm}) {
        push @sqlwhere, $self->{_searchquery}->{hst}->{bool}." match (hst) against (? IN BOOLEAN MODE)";
        push @sqlargs,  $self->{_searchquery}->{hst}->{norm};
    }
  
    if ($self->{_searchquery}->{swt}->{norm}) {
        push @sqlwhere, $self->{_searchquery}->{swt}->{bool}." match (swt) against (? IN BOOLEAN MODE)";
        push @sqlargs,  $self->{_searchquery}->{swt}->{norm};
    }
  
    if ($self->{_searchquery}->{kor}->{norm}) {
        push @sqlwhere, $self->{_searchquery}->{kor}->{bool}." match (kor) against (? IN BOOLEAN MODE)";
        push @sqlargs,  $self->{_searchquery}->{kor}->{norm};
    }
  
    my $notfrom="";
  
    if ($self->{_searchquery}->{notation}->{norm}) {
        # Spezielle Trunkierung
        $self->{_searchquery}->{notation}->{norm} =~ s/\*$/%/;

        push @sqlfrom,  "notation_string";
        push @sqlfrom,  "conn";
        push @sqlwhere, $self->{_searchquery}->{notation}->{bool}." (notation_string.content like ? and conn.sourcetype=1 and conn.targettype=5 and conn.targetid=notation_string.id and search.verwidn=conn.sourceid)";
        push @sqlargs,  $self->{_searchquery}->{notation}->{norm};
    }
  
    if ($self->{_searchquery}->{sign}->{norm}) {
        # Spezielle Trunkierung
        $self->{_searchquery}->{sign}->{norm} =~ s/\*$/%/;

        push @sqlfrom,  "mex_string";
        push @sqlfrom,  "conn";
        push @sqlwhere, $self->{_searchquery}->{sign}->{bool}." (mex_string.content like ? and mex_string.category=0014 and conn.sourcetype=1 and conn.targettype=6 and conn.targetid=mex_string.id and search.verwidn=conn.sourceid)";
        push @sqlargs,  $self->{_searchquery}->{sign}->{norm};
    }
  
    if ($self->{_searchquery}->{isbn}->{norm}) {
        push @sqlwhere, $self->{_searchquery}->{isbn}->{bool}." match (isbn) against (? IN BOOLEAN MODE)";
        push @sqlargs,  $self->{_searchquery}->{isbn}->{norm};
    }
  
    if ($self->{_searchquery}->{issn}->{norm}) {
        push @sqlwhere, $self->{_searchquery}->{issn}->{bool}." match (issn) against (? IN BOOLEAN MODE)";
        push @sqlargs,  $self->{_searchquery}->{issn}->{norm};
    }
  
    if ($self->{_searchquery}->{mart}->{norm}) {
        push @sqlwhere, $self->{_searchquery}->{mart}->{bool}."  match (artinh) against (? IN BOOLEAN MODE)";
        push @sqlargs,  $self->{_searchquery}->{mart}->{norm};
    }
  
    if ($self->{_searchquery}->{hststring}->{norm}) {
        # Spezielle Trunkierung
        $self->{_searchquery}->{hststring}->{norm} =~ s/\*$/%/;

        push @sqlfrom,  "tit_string";
        push @sqlwhere, $self->{_searchquery}->{hststring}->{bool}." (tit_string.content like ? and tit_string.category in (0331,0310,0304,0370,0341) and search.verwidn=tit_string.id)";
        push @sqlargs,  $self->{_searchquery}->{hststring}->{norm};
    }

    if ($self->{_searchquery}->{inhalt}->{norm}) {
        push @sqlwhere, $self->{_searchquery}->{inhalt}->{bool}."  match (inhalt) against (? IN BOOLEAN MODE)";
        push @sqlargs,  $self->{_searchquery}->{inhalt}->{norm};
    }
    
    if ($self->{_searchquery}->{gtquelle}->{norm}) {
        push @sqlwhere, $self->{_searchquery}->{gtquelle}->{bool}."  match (gtquelle) against (? IN BOOLEAN MODE)";
        push @sqlargs,  $self->{_searchquery}->{gtquelle}->{norm};
    }
  
    if ($self->{_searchquery}->{ejahr}->{norm}) {
        push @sqlwhere, $self->{_searchquery}->{ejahr}->{bool}." ejahr ".$self->{_searchquery}->{ejahr}->{arg}." ?";
        push @sqlargs,  $self->{_searchquery}->{ejahr}->{norm};
    }

    if ($serien){
        push @sqlfrom,  "conn";
        push @sqlwhere, "and (conn.targetid=search.verwidn and conn.targettype=1 and conn.sourcetype=1)";
    }

    my $sqlwherestring  = join(" ",@sqlwhere);
    $sqlwherestring     =~s/^(?:AND|OR|NOT) //;
    my $sqlfromstring   = join(", ",@sqlfrom);

    if ($offset >= 0){
        $offset=$offset.",";
    }
    
    my $sqlquerystring  = "select distinct verwidn from $sqlfromstring where $sqlwherestring limit $offset$hitrange";

    return $sqlquerystring;
}

sub get_sql_queryargs {
    my ($self) = @_;
    
    my @sqlargs  = ();

    if ($self->{_searchquery}->{fs}->{norm}) {	
        push @sqlargs, $self->{_searchquery}->{fs}->{norm};
    }
   
    if ($self->{_searchquery}->{verf}->{norm}) {	
        push @sqlargs,  $self->{_searchquery}->{verf}->{norm};
    }
  
    if ($self->{_searchquery}->{hst}->{norm}) {
        push @sqlargs,  $self->{_searchquery}->{hst}->{norm};
    }
  
    if ($self->{_searchquery}->{swt}->{norm}) {
        push @sqlargs,  $self->{_searchquery}->{swt}->{norm};
    }
  
    if ($self->{_searchquery}->{kor}->{norm}) {
        push @sqlargs,  $self->{_searchquery}->{kor}->{norm};
    }
  
    if ($self->{_searchquery}->{notation}->{norm}) {
        # Spezielle Trunkierung
        $self->{_searchquery}->{notation}->{norm} =~ s/\*$/%/;
        push @sqlargs,  $self->{_searchquery}->{notation}->{norm};
    }
  
    if ($self->{_searchquery}->{sign}->{norm}) {
        # Spezielle Trunkierung
        $self->{_searchquery}->{sign}->{norm} =~ s/\*$/%/;
        push @sqlargs,  $self->{_searchquery}->{sign}->{norm};
    }
  
    if ($self->{_searchquery}->{isbn}->{norm}) {
        push @sqlargs,  $self->{_searchquery}->{isbn}->{norm};
    }
  
    if ($self->{_searchquery}->{issn}->{norm}) {
        push @sqlargs,  $self->{_searchquery}->{issn}->{norm};
    }
  
    if ($self->{_searchquery}->{mart}->{norm}) {
        push @sqlargs,  $self->{_searchquery}->{mart}->{norm};
    }
  
    if ($self->{_searchquery}->{hststring}->{norm}) {
        # Spezielle Trunkierung
        $self->{_searchquery}->{hststring}->{norm} =~ s/\*$/%/;
        push @sqlargs,  $self->{_searchquery}->{hststring}->{norm};
    }

    if ($self->{_searchquery}->{inhalt}->{norm}) {
        push @sqlargs,  $self->{_searchquery}->{inhalt}->{norm};
    }
    
    if ($self->{_searchquery}->{gtquelle}->{norm}) {
        push @sqlargs,  $self->{_searchquery}->{gtquelle}->{norm};
    }
  
    if ($self->{_searchquery}->{ejahr}->{norm}) {
        push @sqlargs,  $self->{_searchquery}->{ejahr}->{norm};
    }

    return @sqlargs;
}

1;