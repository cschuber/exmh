Summary: The exmh mail handling system.
Name: exmh
Version: EXMHVERSION 
Release: 1
Requires: mh, metamail
Copyright: freeware
Group: Applications/Mail
BuildArchitectures: noarch
Source0: ftp://ftp.scriptics.com/pub/tcl/exmh/exmh-%{version}.tar.gz
Url: http://www.beedub.com/exmh/
Source1: exmh.wmconfig
Source2: exmh.desktop
# The conf patch includes the version number, so it needs to be
# updated for every revision even if it applies without being
# updated.   Use the exmh.install script to make sure that we
# keep up with new paths that exmh wants to know about, and 
# make sure to change all the paths that need to be changed
# by comparing to the previous conf patch.
Patch0: exmh-%{version}-conf.patch
BuildRoot: %{_tmppath}/%{name}-root

Summary(de): EXMH-Mail-Programm
Summary(fr): Programme de courrier EXMH
Summary(tr): e-posta yazýlýmý
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
exmh ist eine grafische Oberfläche für das MH-Mail-System. Zu den
Funktionen gehören MIME-Unterstützung, Faces, Glimpse-Indexing, 
farbiges Markieren, PGP-Schnittstelle usw. Erfordert sox (oder play)
für Sound-Unterstützung.

%description -l fr
exmh est uen interface graphique au système de courrier MH. Il
gère MIME, les aspects, l'indexation glimpse, la mise en valeur par
couleurs, PGP, et autres. Il faut sox (ou play) pour gérér le son. 

%description -l tr
exmh, yaygýn olarak kullanýlan mh paketi için X11 arayüzüdür. MIME desteði,
PGP desteði, faces, glimpse yardýmýyla dizin oluþturma gibi yetenekleri
vardýr. Ses desteði için sox (ya da play) gerekir.

%prep
%setup -q -n exmh-%{PACKAGE_VERSION}
for i in *.MASTER; do
	cp $i ${i%%.MASTER}
done
%patch0 -p1 -b .conf

%build
echo 'auto_mkindex ./lib *.tcl' | tclsh

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/etc/X11/wmconfig
mkdir -p $RPM_BUILD_ROOT/etc/X11/applnk/Internet
mkdir -p $RPM_BUILD_ROOT{%{_bindir},%{_mandir}/man1}
mkdir -p $RPM_BUILD_ROOT%{_libdir}/exmh-%{version}

for i in exmh exmh-bg exmh-async ftp.expect; do
	install -m755 $i $RPM_BUILD_ROOT/%{_bindir}
done
for i in *.l; do
	install -m644 $i $RPM_BUILD_ROOT%{_mandir}/man1/${i%%.l}.1
done

cp -ar lib/* $RPM_BUILD_ROOT/usr/lib/exmh-%{version}

cp %SOURCE2 $RPM_BUILD_ROOT/etc/X11/applnk/Internet/
install -m644 $RPM_SOURCE_DIR/exmh.wmconfig $RPM_BUILD_ROOT/etc/X11/wmconfig/exmh

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%doc COPYRIGHT exmh.BUGS exmh.CHANGES exmh.TODO exmh.README
%config /etc/X11/wmconfig/exmh 
%config /etc/X11/applnk/Internet/exmh.desktop
%{_bindir}/exmh
%{_bindir}/exmh-bg
%{_bindir}/exmh-async
%{_bindir}/ftp.expect
%{_libdir}/exmh-%{version}
%{_mandir}/man1/exmh.1*

%changelog
* Sat Oct 14 2000 Scott Lipcon <slipcon@acm.jhu.edu>
- changes to support RPM4, bring specfile in line with Redhat's, hopefully

* Sun Aug 20 2000 Scott Lipcon <slipcon@acm.jhu.edu>
- overdue 2.2 patch, fixes pgp6

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

