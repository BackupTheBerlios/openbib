#####################################################################
#
#  Open Library WebServices
#
#  OLWS::Sisis::Data
#
#  Dieses File ist (C) 2005-2009 Oliver Flimm <flimm@openbib.org>
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

package OLWS::Sisis::Data;

use strict;
use warnings;

use Log::Log4perl qw(get_logger :levels);
use Encode qw/encode decode/;

use DBI;

use OLWS::Sisis::Config;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace

use vars qw(%config);

*config=\%OLWS::Sisis::Config::config;

sub get_titdupref_by_katkey {
  my ($dbh,$database,$katkey)=@_;

  # Log4perl logger erzeugen

  my $logger = get_logger();

  my $sql_statement = qq{
  select autor_avs,titel_avs,erschjahr 

  from $database.sisis.titel_dupdaten 

  where katkey = ?
  };
  
  my $request=$dbh->prepare($sql_statement);
  $request->execute($katkey) or $logger->error_die($DBI::errstr);
  
  my $singletitle=undef;
  
  while (my $res=$request->fetchrow_hashref()){
    my $verfasser = ($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$res->{autor_avs})):decode("iso-8859-1",$res->{autor_avs});
    my $titel     = ($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$res->{titel_avs})):decode("iso-8859-1",$res->{titel_avs});
    my $ejahr     = ($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$res->{erschjahr})):decode("iso-8859-1",$res->{erschjahr});
    
    $singletitle={
		  '0100.001'      => $verfasser,
		  '0331.001'      => $titel,
		  '0425.001'      => $ejahr,
		 };
  }
  
  return $singletitle;
}

sub get_titzfl_by_katkey {
  my ($dbh,$database,$katkey)=@_;

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
  my $request=$dbh->prepare("select d10verfasser,d10titel,d10jahr from $database.sisis.d10kat where d10katkey = ?");
  $request->execute($katkey) or $logger->error_die($DBI::errstr);
  
  my $singletitle=undef;
  
  while (my $res=$request->fetchrow_hashref()){
    my $verfasser = ($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$res->{d10verfasser})):decode("iso-8859-1",$res->{d10verfasser});
    my $titel     = ($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$res->{d10titel})):decode("iso-8859-1",$res->{d10titel});
    my $ejahr     = ($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$res->{d10jahr})):decode("iso-8859-1",$res->{d10jahr});
    
    $singletitle={
		  '0100.001'      => $verfasser,
		  '0331.001'      => $titel,
		  '0425.001'      => $ejahr,
		 };
  }
  
  return $singletitle;
}

sub get_titref_by_katkey {
  my ($sikfstabref,$dbh,$database,$katkey)=@_;

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
  my %sikfstab=%$sikfstabref;
  
  my %titel=();
  
  my $request=$dbh->prepare("select nettodaten from $database.sisis.titel_daten where katkey = ?");
  $request->execute($katkey) or $logger->error_die($DBI::errstr);
  
  my $result=$request->fetchrow_hashref();
  
  # Zuweisung der ASCII-Encodeten nettodaten
  my $encdata=$result->{nettodaten};
  
  if ($encdata){    
    my $j = length($encdata);
    
    # Aufloesung der ASCII-Encodeten nettodaten
    my $rawdata = pack "H$j", $encdata;
    
    my $inh="";
    
    $j /= 2;
    my $i = 0;
    my $fnr;
    while ( $i < $j ){
      my $idup = $i*2;
      
      # Aufloesen der 4-stelligen Feldnummer
      $fnr = sprintf "%04d", hex(substr($encdata,$idup,4));
      
      # Kategorie aus der sikfstab holen
      my $kateg = $sikfstab{kateg}[$fnr];
      
      my $len = hex(substr($encdata,$idup+4,4));
      if ( $len < 1000 ){
	# nicht multiples Feld
	$inh = substr($rawdata,$i+4,$len);
	
	# Wenn Feld ein Verweisungsfeld auf Normdaten ist, dann...
	if ( $sikfstab{fldtyp}[$fnr] eq "V" ){
	  my $verwkey = hex(substr($encdata,$idup+8,8));
	  $inh=get_normdata_ans($dbh,$sikfstabref,$database,$verwkey,$fnr,$inh);
	}
	my $KAT = sprintf "%04d", $kateg;
	$titel{$KAT} = ($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$inh)):decode("iso-8859-1",$inh);
	$i = $i + 4 + $len;
      }
      else {
	# multiples Feld
	my $mlen = 65536 - $len;
	my $k = $i + 4;
	my $ukat = 1;
	while ( $k < $i + 4 + $mlen ){
	  my $kdup = $k*2;
	  my $ulen = hex(substr($encdata,$kdup,4));
	  if ( $ulen > 0 ){
	    $inh = substr($rawdata,$k+2,$ulen);
	    if ( $sikfstab{fldtyp}[$fnr] eq "V" ){
	      my $verwkey = hex(substr($encdata,$kdup+4,8));
	      $inh=get_normdata_ans($dbh,$sikfstabref,$database,$verwkey,$fnr,$inh);
	    }
	    my $uKAT = sprintf "%04d.%03d", $kateg, $ukat;
	    $titel{$uKAT} = ($config{utf8_octets})?encode("utf-8",decode("iso-8859-1",$inh)):decode("iso-8859-1",$inh);
	  }
	  $ukat++;
	  $k = $k + 2 + $ulen;
	}
	$i = $i + 4 + $mlen;
      }
    }
  }
  return \%titel;
}	

sub get_raw_titref_by_katkey {
  my ($sikfstabref,$dbh,$database,$katkey)=@_;

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
  my %sikfstab=%$sikfstabref;
  
  my %titel=();
  
  my $request=$dbh->prepare("select nettodaten from $database.sisis.titel_daten where katkey = ?");
  $request->execute($katkey) or $logger->error_die($DBI::errstr);
  
  my $result=$request->fetchrow_hashref();
  
  # Zuweisung der ASCII-Encodeten nettodaten
  my $encdata=$result->{nettodaten};
  
  if ($encdata){    
    my $j = length($encdata);
    
    # Aufloesung der ASCII-Encodeten nettodaten
    my $rawdata = pack "H$j", $encdata;
    
    my $inh="";
    
    $j /= 2;
    my $i = 0;
    my $fnr;
    while ( $i < $j ){
      my $idup = $i*2;
      
      # Aufloesen der 4-stelligen Feldnummer
      $fnr = sprintf "%04d", hex(substr($encdata,$idup,4));
      
      # Kategorie aus der sikfstab holen
      my $kateg = $sikfstab{kateg}[$fnr];
      
      my $len = hex(substr($encdata,$idup+4,4));
      if ( $len < 1000 ){
	# nicht multiples Feld
	$inh = substr($rawdata,$i+4,$len);
	
	# Wenn Feld ein Verweisungsfeld auf Normdaten ist, dann...
	if ( $sikfstab{fldtyp}[$fnr] eq "V" ){
	  $inh=hex(substr($encdata,$idup+8,8));
	}
	my $KAT = sprintf "%04d", $kateg;
	$titel{$KAT} = $inh;
	$i = $i + 4 + $len;
      }
      else {
	# multiples Feld
	my $mlen = 65536 - $len;
	my $k = $i + 4;
	my $ukat = 1;
	while ( $k < $i + 4 + $mlen ){
	  my $kdup = $k*2;
	  my $ulen = hex(substr($encdata,$kdup,4));
	  if ( $ulen > 0 ){
	    $inh = substr($rawdata,$k+2,$ulen);
	    if ( $sikfstab{fldtyp}[$fnr] eq "V" ){
	      $inh=hex(substr($encdata,$kdup+4,8));
	    }
	    my $uKAT = sprintf "%04d.%03d", $kateg, $ukat;
	    $titel{$uKAT} = $inh;
	  }
	  $ukat++;
	  $k = $k + 2 + $ulen;
	}
	$i = $i + 4 + $mlen;
      }
    }
  }
  return \%titel;
}	

sub get_raw_autref_by_katkey {
  my ($sikfstabref,$dbh,$database,$katkey)=@_;

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
  my %sikfstab=%$sikfstabref;
  
  my %rawset=();
  
  my $request=$dbh->prepare("select nettodaten from $database.sisis.per_daten where katkey = ? and aktion = 0");
  $request->execute($katkey) or $logger->error_die($DBI::errstr);
  
  my $result=$request->fetchrow_hashref();
  
  # Zuweisung der ASCII-Encodeten nettodaten
  my $encdata=$result->{nettodaten};
  
  if ($encdata){    
    my $j = length($encdata);
    
    # Aufloesung der ASCII-Encodeten nettodaten
    my $rawdata = pack "H$j", $encdata;
    
    my $inh="";
    
    $j /= 2;
    my $i = 0;
    my $fnr;
    while ( $i < $j ){
      my $idup = $i*2;
      
      # Aufloesen der 4-stelligen Feldnummer
      $fnr = sprintf "%04d", hex(substr($encdata,$idup,4));
      
      # Kategorie aus der sikfstab holen
      my $kateg = $sikfstab{kateg}[$fnr];
      
      my $len = hex(substr($encdata,$idup+4,4));
      if ( $len < 1000 ){
	# nicht multiples Feld
	$inh = substr($rawdata,$i+4,$len);

        if ( substr($inh,0,1) eq " " ){
	  $inh =~ s/^ //;
        }
      
        # Schmutzzeichen weg
        $inh=~s/^ //;

	my $KAT = sprintf "%04d", $kateg;
	$rawset{$KAT} = $inh;
	$i = $i + 4 + $len;
      }
      else {
	# multiples Feld
	my $mlen = 65536 - $len;
	my $k = $i + 4;
	my $ukat = 1;
	while ( $k < $i + 4 + $mlen ){
	  my $kdup = $k*2;
	  my $ulen = hex(substr($encdata,$kdup,4));
	  if ( $ulen > 0 ){
	    $inh = substr($rawdata,$k+2,$ulen);

            if ( substr($inh,0,1) eq " " ){
	      $inh =~ s/^ //;
            }
      
            # Schmutzzeichen weg
            $inh=~s/^ //;

	    my $uKAT = sprintf "%04d.%03d", $kateg, $ukat;
	    $rawset{$uKAT} = $inh;
	  }
	  $ukat++;
	  $k = $k + 2 + $ulen;
	}
	$i = $i + 4 + $mlen;
      }
    }
  }
  return \%rawset;
}	

sub get_raw_korref_by_katkey {
  my ($sikfstabref,$dbh,$database,$katkey)=@_;

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
  my %sikfstab=%$sikfstabref;
  
  my %rawset=();
  
  my $request=$dbh->prepare("select nettodaten from $database.sisis.koe_daten where katkey = ? and aktion = 0");
  $request->execute($katkey) or $logger->error_die($DBI::errstr);
  
  my $result=$request->fetchrow_hashref();
  
  # Zuweisung der ASCII-Encodeten nettodaten
  my $encdata=$result->{nettodaten};
  
  if ($encdata){    
    my $j = length($encdata);
    
    # Aufloesung der ASCII-Encodeten nettodaten
    my $rawdata = pack "H$j", $encdata;
    
    my $inh="";
    
    $j /= 2;
    my $i = 0;
    my $fnr;
    while ( $i < $j ){
      my $idup = $i*2;
      
      # Aufloesen der 4-stelligen Feldnummer
      $fnr = sprintf "%04d", hex(substr($encdata,$idup,4));
      
      # Kategorie aus der sikfstab holen
      my $kateg = $sikfstab{kateg}[$fnr];
      
      my $len = hex(substr($encdata,$idup+4,4));
      if ( $len < 1000 ){
	# nicht multiples Feld
	$inh = substr($rawdata,$i+4,$len);

        if ( substr($inh,0,1) eq " " ){
	  $inh =~ s/^ //;
        }
      
        # Schmutzzeichen weg
        $inh=~s/^ //;

	my $KAT = sprintf "%04d", $kateg;
	$rawset{$KAT} = $inh;
	$i = $i + 4 + $len;
      }
      else {
	# multiples Feld
	my $mlen = 65536 - $len;
	my $k = $i + 4;
	my $ukat = 1;
	while ( $k < $i + 4 + $mlen ){
	  my $kdup = $k*2;
	  my $ulen = hex(substr($encdata,$kdup,4));
	  if ( $ulen > 0 ){
	    $inh = substr($rawdata,$k+2,$ulen);

            if ( substr($inh,0,1) eq " " ){
	      $inh =~ s/^ //;
            }
      
            # Schmutzzeichen weg
            $inh=~s/^ //;

	    my $uKAT = sprintf "%04d.%03d", $kateg, $ukat;
	    $rawset{$uKAT} = $inh;
	  }
	  $ukat++;
	  $k = $k + 2 + $ulen;
	}
	$i = $i + 4 + $mlen;
      }
    }
  }
  return \%rawset;
}	

sub get_raw_swtref_by_katkey {
  my ($sikfstabref,$dbh,$database,$katkey)=@_;

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
  my %sikfstab=%$sikfstabref;
  
  my %rawset=();
  
  my $request=$dbh->prepare("select nettodaten from $database.sisis.swd_daten where katkey = ? and aktion = 0");
  $request->execute($katkey) or $logger->error_die($DBI::errstr);
  
  my $result=$request->fetchrow_hashref();
  
  # Zuweisung der ASCII-Encodeten nettodaten
  my $encdata=$result->{nettodaten};
  
  if ($encdata){    
    my $j = length($encdata);
    
    # Aufloesung der ASCII-Encodeten nettodaten
    my $rawdata = pack "H$j", $encdata;
    
    my $inh="";
    
    $j /= 2;
    my $i = 0;
    my $fnr;
    while ( $i < $j ){
      my $idup = $i*2;
      
      # Aufloesen der 4-stelligen Feldnummer
      $fnr = sprintf "%04d", hex(substr($encdata,$idup,4));
      
      # Kategorie aus der sikfstab holen
      my $kateg = $sikfstab{kateg}[$fnr];
      
      my $len = hex(substr($encdata,$idup+4,4));
      if ( $len < 1000 ){
	# nicht multiples Feld
	$inh = substr($rawdata,$i+4,$len);

        if ( substr($inh,0,1) eq " " ){
	  $inh =~ s/^ //;
        }
      
        # Schmutzzeichen weg
        $inh=~s/^ //;

	my $KAT = sprintf "%04d", $kateg;
	$rawset{$KAT} = $inh;
	$i = $i + 4 + $len;
      }
      else {
	# multiples Feld
	my $mlen = 65536 - $len;
	my $k = $i + 4;
	my $ukat = 1;
	while ( $k < $i + 4 + $mlen ){
	  my $kdup = $k*2;
	  my $ulen = hex(substr($encdata,$kdup,4));
	  if ( $ulen > 0 ){
	    $inh = substr($rawdata,$k+2,$ulen);

            if ( substr($inh,0,1) eq " " ){
	      $inh =~ s/^ //;
            }
      
            # Schmutzzeichen weg
            $inh=~s/^ //;

	    my $uKAT = sprintf "%04d.%03d", $kateg, $ukat;
	    $rawset{$uKAT} = $inh;
	  }
	  $ukat++;
	  $k = $k + 2 + $ulen;
	}
	$i = $i + 4 + $mlen;
      }
    }
  }
  return \%rawset;
}	

sub get_raw_notref_by_katkey {
  my ($sikfstabref,$dbh,$database,$katkey)=@_;

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
  my %sikfstab=%$sikfstabref;
  
  my %rawset=();
  
  my $request=$dbh->prepare("select nettodaten from $database.sisis.sys_daten where katkey = ? and aktion = 0");
  $request->execute($katkey) or $logger->error_die($DBI::errstr);
  
  my $result=$request->fetchrow_hashref();
  
  # Zuweisung der ASCII-Encodeten nettodaten
  my $encdata=$result->{nettodaten};
  
  if ($encdata){    
    my $j = length($encdata);
    
    # Aufloesung der ASCII-Encodeten nettodaten
    my $rawdata = pack "H$j", $encdata;
    
    my $inh="";
    
    $j /= 2;
    my $i = 0;
    my $fnr;
    while ( $i < $j ){
      my $idup = $i*2;
      
      # Aufloesen der 4-stelligen Feldnummer
      $fnr = sprintf "%04d", hex(substr($encdata,$idup,4));
      
      # Kategorie aus der sikfstab holen
      my $kateg = $sikfstab{kateg}[$fnr];
      
      my $len = hex(substr($encdata,$idup+4,4));
      if ( $len < 1000 ){
	# nicht multiples Feld
	$inh = substr($rawdata,$i+4,$len);

        if ( substr($inh,0,1) eq " " ){
	  $inh =~ s/^ //;
        }
      
        # Schmutzzeichen weg
        $inh=~s/^ //;

	my $KAT = sprintf "%04d", $kateg;
	$rawset{$KAT} = $inh;
	$i = $i + 4 + $len;
      }
      else {
	# multiples Feld
	my $mlen = 65536 - $len;
	my $k = $i + 4;
	my $ukat = 1;
	while ( $k < $i + 4 + $mlen ){
	  my $kdup = $k*2;
	  my $ulen = hex(substr($encdata,$kdup,4));
	  if ( $ulen > 0 ){
	    $inh = substr($rawdata,$k+2,$ulen);

            if ( substr($inh,0,1) eq " " ){
	      $inh =~ s/^ //;
            }
      
            # Schmutzzeichen weg
            $inh=~s/^ //;

	    my $uKAT = sprintf "%04d.%03d", $kateg, $ukat;
	    $rawset{$uKAT} = $inh;
	  }
	  $ukat++;
	  $k = $k + 2 + $ulen;
	}
	$i = $i + 4 + $mlen;
      }
    }
  }
  return \%rawset;
}	

sub get_sikfstabref {
  my ($dbh,$database)=@_;

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
  my $request=$dbh->prepare("select fnr, kateg, fldtyp, refnr from $database.sisis.sik_fstab where setnr=1");
  $request->execute() or $logger->error_die($DBI::errstr);
  
  my %sikfstab=();
  
  while (my $result=$request->fetchrow_hashref()){
    my $fnr=$result->{fnr};
    $sikfstab{kateg}[$fnr]  = $result->{kateg};	
    $sikfstab{fldtyp}[$fnr] = $result->{fldtyp};
    $sikfstab{refnr}[$fnr]  = $result->{refnr};
  }
  
  $request->finish();
  
  return \%sikfstab;
}


sub get_normdata_ans {
  my ($dbh,$sikfstabref,$database,$verwkey,$fnr,$inh)=@_;

  # Log4perl logger erzeugen

  my $logger = get_logger();
  
  my %sikfstab=%$sikfstabref;
  
  my @normtabs = ("per_daten", "koe_daten", "swd_daten", "sys_daten");
  
  my $nansetzung = "";
  
  my $tabelle=$normtabs[$sikfstab{refnr}[$fnr]-1];
  
  my $request=$dbh->prepare("select nettodaten from $database.sisis.$tabelle where katkey = ?");
  $request->execute($verwkey) or $logger->error_die($DBI::errstr);
  
  my $result=$request->fetchrow_hashref();
  
  # Zuweisung der ASCII-Encodeten nettodaten
  my $encdata=$result->{nettodaten};
  
  $request->finish();
  
  if ($encdata){    
    my $j = length($encdata);
    my $rawdata = pack "H$j", $encdata;
    $j /= 2;
    my $i = 0;
    
    while ( $i < $j ){
      my $idup = $i*2;
      my $fnr = sprintf "%04d", hex(substr($encdata,$idup,4));
      my $len = hex(substr($encdata,$idup+4,4));
      my $ansetzung;
      if ( $len < 1000 ){
	# nicht multiples Feld
	if ( $fnr == 1 ){
	  $ansetzung = substr($rawdata,$i+4,$len);
	  if ( substr($ansetzung,0,1) eq " " ){
	    $ansetzung =~ s/^ //;
	  }
	  else {
	    $ansetzung = "(" . substr($ansetzung,0,1) . ")" . substr($ansetzung,1);
	  }
	  $i = $j + 1;
	}
	else {
	  $i = $i + 4 + $len;
	}
      }
      else {
	# multiples Feld
	my $mlen = 65536 - $len;
	if ( $fnr == 1 ){
	  my $k = $i + 4;
	  my $ukat = 1;
	  $ansetzung = "";
	  while ( $k < $i + 4 + $mlen ){
	    my $kdup = $k*2;
	    my $ulen = hex(substr($encdata,$kdup,4));
	    if ( $ulen > 0 ){
	      if ( $ansetzung ne "" ){
		$ansetzung .= " / ";
	      }
	      $inh = substr($rawdata,$k+2,$ulen);
	      if ( substr($inh,0,1) eq " " ){
		$inh =~ s/^ //;
	      }
	      else {
		$inh = "(" . substr($inh,0,1) . ")" . substr($inh,1);
	      }
	      $ansetzung .= $inh;
	    }
	    $ukat++;
	    $k = $k + 2 + $ulen;
	  }
	  $i = $j + 1;
	}
	else {
	  $i = $i + 4 + $mlen;
	}
      }
      
      if ( length($inh) == 4 ){
	# Einfacher Inhalt ohne Bezeichner
	$inh = $ansetzung;
      }
      else {
	# Zusaetzlicher Bezeichner ala [Bearb.] etc. muss nachgestellt
	# werden
	$inh = $ansetzung . substr($inh,4);
      }
    }
  }
  return $inh;
}

1;
