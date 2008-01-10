#####################################################################
#
#  OpenBib::Handler::Apache::UserPrefs
#
#  Dieses File ist (C) 2004-2006 Oliver Flimm <flimm@openbib.org>
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

package OpenBib::Handler::Apache::UserPrefs;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Apache::Constants qw(:common);
use Apache::Reload;
use Apache::Request ();
use DBI;
use Email::Valid;
use Encode 'decode_utf8';
use Log::Log4perl qw(get_logger :levels);
use POSIX;
use Template;

use OpenBib::Common::Util;
use OpenBib::Config;
use OpenBib::L10N;
use OpenBib::Session;
use OpenBib::User;

sub handler {
    my $r=shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $config = new OpenBib::Config();
    
    my $query=Apache::Request->instance($r);

    my $status=$query->parse;

    if ($status) {
        $logger->error("Cannot parse Arguments - ".$query->notes("error-notes"));
    }

    my $session   = new OpenBib::Session({
        sessionID => $query->param('sessionID'),
    });

    my $user      = new OpenBib::User({sessionID => $session->{ID}});
    
    my $stylesheet=OpenBib::Common::Util::get_css_by_browsertype($r);

    my $showfs        = ($query->param('showfs'))?$query->param('showfs'):'0';
    my $showhst       = ($query->param('showhst'))?$query->param('showhst'):'0';
    my $showhststring = ($query->param('showhststring'))?$query->param('showhststring'):'0';
    my $showgtquelle  = ($query->param('showgtquelle'))?$query->param('showgtquelle'):'0';
    my $showverf      = ($query->param('showverf'))?$query->param('showverf'):'0';
    my $showkor       = ($query->param('showkor'))?$query->param('showkor'):'0';
    my $showswt       = ($query->param('showswt'))?$query->param('showswt'):'0';
    my $shownotation  = ($query->param('shownotation'))?$query->param('shownotation'):'0';
    my $showisbn      = ($query->param('showisbn'))?$query->param('showisbn'):'0';
    my $showissn      = ($query->param('showissn'))?$query->param('showissn'):'0';
    my $showsign      = ($query->param('showsign'))?$query->param('showsign'):'0';
    my $showinhalt    = ($query->param('showinhalt'))?$query->param('showinhalt'):'0';
    my $showmart      = ($query->param('showmart'))?$query->param('showmart'):'0';
    my $showejahr     = ($query->param('showejahr'))?$query->param('showejahr'):'0';

    my $setmask       = ($query->param('setmask'))?$query->param('setmask'):'';
    my $action        = ($query->param('action'))?$query->param('action'):'none';
    my $targetid      = ($query->param('targetid'))?$query->param('targetid'):'none';
    my $loginname     = ($query->param('loginname'))?$query->param('loginname'):'';
    my $password      = ($query->param('password'))?$query->param('password'):'';
    my $password1     = ($query->param('password1'))?$query->param('password1'):'';
    my $password2     = ($query->param('password2'))?$query->param('password2'):'';
  
    my $queryoptions_ref
        = $session->get_queryoptions($query);

    # Message Katalog laden
    my $msg = OpenBib::L10N->get_handle($queryoptions_ref->{l}) || $logger->error("L10N-Fehler");
    $msg->fail_with( \&OpenBib::L10N::failure_handler );

    if (!$session->is_valid()){
        OpenBib::Common::Util::print_warning($msg->maketext("Ungültige Session"),$r,$msg);
        return OK;
    }

    my $view="";

    if ($query->param('view')) {
        $view=$query->param('view');
    }
    else {
        $view=$session->get_viewname();
    }

    unless($user->{ID}){
        OpenBib::Common::Util::print_warning($msg->maketext("Diese Session ist nicht authentifiziert."),$r,$msg);
        return OK;
    }
  
    if ($action eq "showfields") {
        my $targetresult=$user->{dbh}->prepare("select * from fieldchoice where userid = ?") or $logger->error($DBI::errstr);
        $targetresult->execute($user->{ID}) or $logger->error($DBI::errstr);
    
        my $result=$targetresult->fetchrow_hashref();
    
        my $showfs = decode_utf8($result->{'fs'});
        my $fschecked="";
        $fschecked="checked=\"checked\"" if ($showfs);
    
        my $showhst = decode_utf8($result->{'hst'});
        my $hstchecked="";
        $hstchecked="checked=\"checked\"" if ($showhst);

        my $showgtquelle = decode_utf8($result->{'gtquelle'});
        my $gtquellechecked="";
        $gtquellechecked="checked=\"checked\"" if ($showgtquelle);

        my $showinhalt = decode_utf8($result->{'inhalt'});
        my $inhaltchecked="";
        $inhaltchecked="checked=\"checked\"" if ($showinhalt);

        my $showhststring = decode_utf8($result->{'hststring'});
        my $hststringchecked="";
        $hststringchecked="checked=\"checked\"" if ($showhststring);
    
        my $showverf = decode_utf8($result->{'verf'});
        my $verfchecked="";
        $verfchecked="checked=\"checked\"" if ($showverf);
    
        my $showkor = decode_utf8($result->{'kor'});
        my $korchecked="";
        $korchecked="checked=\"checked\"" if ($showkor);
    
        my $showswt = decode_utf8($result->{'swt'});
        my $swtchecked="";
        $swtchecked="checked=\"checked\"" if ($showswt);
    
        my $shownotation = decode_utf8($result->{'notation'});
        my $notationchecked="";
        $notationchecked="checked=\"checked\"" if ($shownotation);
    
        my $showisbn = decode_utf8($result->{'isbn'});
        my $isbnchecked="";
        $isbnchecked="checked=\"checked\"" if ($showisbn);
    
        my $showissn = decode_utf8($result->{'issn'});
        my $issnchecked="";
        $issnchecked="checked=\"checked\"" if ($showissn);
    
        my $showsign = decode_utf8($result->{'sign'});
        my $signchecked="";
        $signchecked="checked=\"checked\"" if ($showsign);
    
        my $showmart = decode_utf8($result->{'mart'});
        my $martchecked="";
        $martchecked="checked=\"checked\"" if ($showmart);
    
        my $showejahr = decode_utf8($result->{'ejahr'});
        my $ejahrchecked="";
        $ejahrchecked="checked=\"checked\"" if ($showejahr);
    
        $targetresult->finish();
    
        my $userresult=$user->{dbh}->prepare("select * from user where userid = ?") or $logger->error($DBI::errstr);
        $userresult->execute($user->{ID}) or $logger->error($DBI::errstr);
    
        my $res=$userresult->fetchrow_hashref();
    
        my %userinfo=();

        $userinfo{'nachname'}   = decode_utf8($res->{'nachname'});
        $userinfo{'vorname'}    = decode_utf8($res->{'vorname'});
        $userinfo{'strasse'}    = decode_utf8($res->{'strasse'});
        $userinfo{'ort'}        = decode_utf8($res->{'ort'});
        $userinfo{'plz'}        = decode_utf8($res->{'plz'});
        $userinfo{'soll'}       = decode_utf8($res->{'soll'});
        $userinfo{'gut'}        = decode_utf8($res->{'gut'});
        $userinfo{'avanz'}      = decode_utf8($res->{'avanz'}); # Ausgeliehene Medien
        $userinfo{'branz'}      = decode_utf8($res->{'branz'}); # Buchrueckforderungen
        $userinfo{'bsanz'}      = decode_utf8($res->{'bsanz'}); # Bestellte Medien
        $userinfo{'vmanz'}      = decode_utf8($res->{'vmanz'}); # Vormerkungen
        $userinfo{'maanz'}      = decode_utf8($res->{'maanz'}); # ueberzogene Medien
        $userinfo{'vlanz'}      = decode_utf8($res->{'vlanz'}); # Verlaengerte Medien
        $userinfo{'sperre'}     = decode_utf8($res->{'sperre'});
        $userinfo{'sperrdatum'} = decode_utf8($res->{'sperrdatum'});
        $userinfo{'email'}      = decode_utf8($res->{'email'});
        $userinfo{'gebdatum'}   = decode_utf8($res->{'gebdatum'});
        $userinfo{'masktype'}   = decode_utf8($res->{'masktype'});

        my $loginname           = decode_utf8($res->{'loginname'});
        my $password            = decode_utf8($res->{'pin'});
    
        my $passwortaenderung = "";
        my $loeschekennung    = "";
    
        # Wenn wir eine gueltige Mailadresse als Loginnamen haben,
        # dann liegt Selbstregistrierung vor und das Passwort kann
        # geaendert werden
        my $email_valid=Email::Valid->address($loginname);

        my $targettype=$user->get_targettype_of_session($session->{ID});

        # TT-Data erzeugen
        my $ttdata={
            view             => $view,
            stylesheet       => $stylesheet,
            sessionID        => $session->{ID},
            user             => $user,
            
            loginname        => $loginname,
            password         => $password,
            email_valid      => $email_valid,
            targettype       => $targettype,
            fschecked        => $fschecked,
            hstchecked       => $hstchecked,
            hststringchecked => $hststringchecked,
            verfchecked      => $verfchecked,
            korchecked       => $korchecked,
            swtchecked       => $swtchecked,
            notationchecked  => $notationchecked,
            isbnchecked      => $isbnchecked,
            issnchecked      => $issnchecked,
            inhaltchecked    => $inhaltchecked,
            signchecked      => $signchecked,
            martchecked      => $martchecked,
            ejahrchecked     => $ejahrchecked,
            userinfo         => \%userinfo,

            config           => $config,
            msg              => $msg,
        };
        OpenBib::Common::Util::print_page($config->{tt_userprefs_tname},$ttdata,$r);
    }
    elsif ($action eq "changefields") {
        my $targetresult=$user->{dbh}->prepare("update fieldchoice set fs = ?, hst = ?, hststring = ?, verf = ?, kor = ?, swt = ?, notation = ?, isbn = ?, issn = ?, sign = ?, mart = ?, ejahr = ?, inhalt=?, gtquelle=? where userid = ?") or $logger->error($DBI::errstr);
        $targetresult->execute($showfs,$showhst,$showhststring,$showverf,$showkor,$showswt,$shownotation,$showisbn,$showissn,$showsign,$showmart,$showejahr,$showinhalt,$showgtquelle,$user->{ID}) or $logger->error($DBI::errstr);
        $targetresult->finish();

        # TT-Data erzeugen
        my $ttdata={
            view       => $view,
            stylesheet => $stylesheet,
            sessionID  => $session->{ID},

            config     => $config,
            msg        => $msg,
        };
        OpenBib::Common::Util::print_page($config->{tt_userprefs_changefields_tname},$ttdata,$r);
    }
    elsif ($action eq "delaccount_ask") {
        # TT-Data erzeugen
        my $ttdata={
            view       => $view,
            stylesheet => $stylesheet,
            sessionID  => $session->{ID},

            config     => $config,
            msg        => $msg,
        };
        OpenBib::Common::Util::print_page($config->{tt_userprefs_ask_delete_tname},$ttdata,$r);
    }
    elsif ($action eq "delaccount") {
        # Zuerst werden die Datenbankprofile geloescht
        my $userresult;
        $userresult=$user->{dbh}->prepare("delete from profildb using profildb,userdbprofile where userdbprofile.userid = ? and userdbprofile.profilid=profildb.profilid") or $logger->error($DBI::errstr);
        $userresult->execute($user->{ID}) or $logger->error($DBI::errstr);
    
        $userresult=$user->{dbh}->prepare("delete from userdbprofile where userdbprofile.userid = ?") or $logger->error($DBI::errstr);
        $userresult->execute($user->{ID}) or $logger->error($DBI::errstr);
    
        # .. dann die Suchfeldeinstellungen
        $userresult=$user->{dbh}->prepare("delete from fieldchoice where userid = ?") or $logger->error($DBI::errstr);
        $userresult->execute($user->{ID}) or $logger->error($DBI::errstr);
    
        # .. dann die Merkliste
        $userresult=$user->{dbh}->prepare("delete from treffer where userid = ?") or $logger->error($DBI::errstr);
        $userresult->execute($user->{ID}) or $logger->error($DBI::errstr);
    
        # .. dann die Verknuepfung zur Session
        $userresult=$user->{dbh}->prepare("delete from usersession where userid = ?") or $logger->error($DBI::errstr);
        $userresult->execute($user->{ID}) or $logger->error($DBI::errstr);
    
        # und schliesslich der eigentliche Benutzereintrag
        $userresult=$user->{dbh}->prepare("delete from user where userid = ?") or $logger->error($DBI::errstr);
        $userresult->execute($user->{ID}) or $logger->error($DBI::errstr);
    
        $userresult->finish();

        # Als naechstes werden die 'normalen' Sessiondaten geloescht
        # Zuallererst loeschen der Trefferliste fuer diese sessionID
        my $idnresult;
        $idnresult=$session->{dbh}->prepare("delete from treffer where sessionid = ?") or $logger->error($DBI::errstr);
        $idnresult->execute($session->{ID}) or $logger->error($DBI::errstr);
    
        $idnresult=$session->{dbh}->prepare("delete from dbchoice where sessionid = ?") or $logger->error($DBI::errstr);
        $idnresult->execute($session->{ID}) or $logger->error($DBI::errstr);
    
        $idnresult=$session->{dbh}->prepare("delete from searchresults where sessionid = ?") or $logger->error($DBI::errstr);
        $idnresult->execute($session->{ID}) or $logger->error($DBI::errstr);
    
        $idnresult=$session->{dbh}->prepare("delete from sessionview where sessionid = ?") or $logger->error($DBI::errstr);
        $idnresult->execute($session->{ID}) or $logger->error($DBI::errstr);
    
        $idnresult->finish();

        # TT-Data erzeugen
        my $ttdata={
            view       => $view,
            stylesheet => $stylesheet,
            sessionID  => $session->{ID},

            config     => $config,
            msg        => $msg,
        };
        OpenBib::Common::Util::print_page($config->{tt_userprefs_userdeleted_tname},$ttdata,$r);
    }
    elsif ($action eq "changepw") {
        if ($password1 eq "" || $password1 ne $password2) {
            OpenBib::Common::Util::print_warning($msg->maketext("Sie haben entweder kein Passwort eingegeben oder die beiden Passworte stimmen nicht überein"),$r,$msg);
            return OK;
        }
    
        my $targetresult=$user->{dbh}->prepare("update user set pin = ? where userid = ?") or $logger->error($DBI::errstr);
        $targetresult->execute($password1,$user->{ID}) or $logger->error($DBI::errstr);
        $targetresult->finish();
    
        $r->internal_redirect("http://$config->{servername}$config->{userprefs_loc}?sessionID=$session->{ID}&action=showfields");
    }
    elsif ($action eq "changemask") {
        if ($setmask eq "") {
            OpenBib::Common::Util::print_warning($msg->maketext("Es wurde keine Standard-Recherchemaske ausgewählt"),$r,$msg);
            return OK;
        }
    
        my $targetresult=$user->{dbh}->prepare("update user set masktype = ? where userid = ?") or $logger->error($DBI::errstr);
        $targetresult->execute($setmask,$user->{ID}) or $logger->error($DBI::errstr);
        $targetresult->finish();

        $session->set_mask($setmask);

        $r->internal_redirect("http://$config->{servername}$config->{userprefs_loc}?sessionID=$session->{ID}&action=showfields");
    }
    else {
        OpenBib::Common::Util::print_warning($msg->maketext("Unerlaubte Aktion"),$r,$msg);
    }
    return OK;
}

1;
__END__

=head1 NAME

OpenBib::UserPrefs - Verwaltung von Benutzer-Profil-Einstellungen

=head1 DESCRIPTION

Das mod_perl-Modul OpenBib::UserPrefs stellt dem Benutzer des 
Suchportals Einstellmoeglichkeiten seines persoenlichen Profils
zur Verfuegung.

=head2 Loeschung seiner Kennung

Loeschung seiner Kennung, so es sich um eine Kennung handelt, die 
im Rahmen der Selbstregistrierung angelegt wurde. Sollte der
Benutzer sich mit einer Kennung aus einer Sisis-Datenbank 
authentifiziert haben, so wird ihm die Loeschmoeglichkeit nicht 
angeboten
 

=head1 AUTHOR

 Oliver Flimm <flimm@openbib.org>

=cut