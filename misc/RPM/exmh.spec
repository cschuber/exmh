Summary: EXMH mail program
Name: exmh
Version: 2.1.2
Release: 1
Requires: mh metamail
Copyright: freeware
Group: Applications/Mail
BuildArchitectures: noarch
Source0: ftp://ftp.scriptics.com/pub/tcl/exmh/exmh-2.1.2.tar.gz
Url: http://www.beedub.com/exmh/
Source1: exmh.wmconfig
Patch1: exmh-2.1.2-conf.patch
BuildRoot: /var/tmp/exmh-root
Summary(de): EXMH-Mail-Programm
Summary(fr): Programme de courrier EXMH
Summary(tr): e-posta yaz�l�m�
Summary(es): Pograma lector de correo exmh

%description
exmh is a graphical interface to the MH mail system.  It includes
MIME support, faces, glimpse indexing, color highlighting, PGP
interface, and more.  Requires sox (or play) for sound support.

%description -l es
exmh es un interface grafico para el sistema de correo MH. Incluye
soporte para tipos MIME, faces, indexacion mediante glimpse, 
marcado en colores de las cabeceras, PGP y GPGP, enlaces URL, y 
muchas mas cosas. Necesita sox (o play) para el sonido

%description -l de
exmh ist eine grafische Oberfl�che f�r das MH-Mail-System. Zu den
Funktionen geh�ren MIME-Unterst�tzung, Faces, Glimpse-Indexing, 
farbiges Markieren, PGP-Schnittstelle usw. Erfordert sox (oder play)
f�r Sound-Unterst�tzung.

%description -l fr
exmh est uen interface graphique au syst�me de courrier MH. Il
g�re MIME, les aspects, l'indexation glimpse, la mise en valeur par
couleurs, PGP, et autres. Il faut sox (ou play) pour g�r�r le son. 

%description -l tr
exmh, yayg�n olarak kullan�lan mh paketi i�in X11 aray�z�d�r. MIME deste�i,
PGP deste�i, faces, glimpse yard�m�yla dizin olu�turma gibi yetenekleri
vard�r. Ses deste�i i�in sox (ya da play) gerekir.

%prep
%setup -q -n exmh-%{PACKAGE_VERSION}
for i in *.MASTER; do
	cp $i ${i%%.MASTER}
done
%patch1 -p1
find . -name "*.orig" -exec rm {} \;

%build
echo 'auto_mkindex ./lib *.tcl' | tclsh

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/etc/X11/wmconfig
mkdir -p $RPM_BUILD_ROOT/usr/{bin,man/man1}
mkdir -p $RPM_BUILD_ROOT/usr/lib/exmh-%{PACKAGE_VERSION}

for i in exmh exmh-bg exmh-async ftp.expect; do
	install -m755 $i $RPM_BUILD_ROOT/usr/bin
done
for i in *.l; do
	install -m644 $i $RPM_BUILD_ROOT/usr/man/man1/${i%%.l}.1
done

cp -ar lib/* $RPM_BUILD_ROOT/usr/lib/exmh-%{PACKAGE_VERSION}

install -m644 $RPM_SOURCE_DIR/exmh.wmconfig $RPM_BUILD_ROOT/etc/X11/wmconfig/exmh

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%doc COPYRIGHT exmh.BUGS exmh.CHANGES exmh.TODO exmh.README
%config /etc/X11/wmconfig/exmh
/usr/bin/exmh
/usr/bin/exmh-bg
/usr/bin/exmh-async
/usr/bin/ftp.expect
/usr/lib/exmh-%{PACKAGE_VERSION}
/usr/man/man1/exmh.1

%changelog
* Wed Jun 07 2000 Scott Lipcon <slipcon@acm.jhu.edu>
- update for exmh 2.1.2, coming soon.

* Fri Sep 17 1999 Scott Lipcon <slipcon@acm.jhu.edu>
- Added Spanish translation, courtesy of Francisco 
  Monserrat <francisco.monserrat@rediris.es>
  
* Thu Jul 29 1999 Scott Lipcon <slipcon@acm.jhu.edu>
- update to exmh 2.1.0, add spec file to distribution, and 
  added a 'rpm' target to the Makefile

* Tue Mar 03 1999 Scott Lipcon <slipcon@acm.jhu.edu>
- update to exmh 2.0.3

* Sat Aug 15 1998 Jeff Johnson <jbj@redhat.com>
- build root

* Fri Apr 24 1998 Prospector System <bugs@redhat.com>
- translations modified for de, fr, tr

* Fri Apr 10 1998 Donnie Barnes <djb@redhat.com>
- updated to 2.0.2

* Wed Oct 22 1997 Donnie Barnes <djb@redhat.com>
- added wmconfig support

