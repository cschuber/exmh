# Create a tar distribution for exmh

# Remember to update exmh.install when changing version numbers.

VERSION=2.2
SNAPDATE=`/bin/date +%Y%m%d`

srctar: version htmltar
	echo ./CVS > Tar.exclude
	echo ./lib/CVS >> Tar.exclude
	echo ./misc/CVS >> Tar.exclude
	echo ./misc/RPM/CVS >> Tar.exclude
	echo ./lib/html/CVS >> Tar.exclude
	echo ./lib/html/Tar.exclude >> Tar.exclude
	echo ./.exmhinstall >> Tar.exclude
	echo ./Tar.exclude >> Tar.exclude
	echo ./html-\*.tar.gz >> Tar.exclude
	echo ./exmh-\*.tar.gz >> Tar.exclude
	echo ./exmh-\*.src.rpm >> Tar.exclude
	echo ./exmh-\*.noarch.rpm >> Tar.exclude
	echo ./rpmroot >> Tar.exclude
	rm -rf /tmp/exmh-$(VERSION)
	mkdir /tmp/exmh-$(VERSION)
	tar cvfX - Tar.exclude . | (cd /tmp/exmh-$(VERSION) ; tar xf -)
	(cd /tmp ; tar cf - exmh-$(VERSION) | gzip > /tmp/exmh-$(VERSION).tar.gz)
	mv /tmp/exmh-$(VERSION).tar.gz .
	rm -rf /tmp/exmh-$(VERSION)

clean:
	rm -f ./Tar.exclude
	rm -f ./lib/html/Tar.exclude
	rm -f ./exmh-*.tar.gz
	rm -f ./html-*.tar.gz
	rm -f ./exmh-*.noarch.rpm
	rm -f ./exmh-*.src.rpm
	rm -f ./lib/html/exmh.CHANGES.txt
	rm -rf ./rpmroot/

rpm:	srctar
	mkdir -p rpmroot/{SOURCES,SPECS,BUILDROOT,RPMS/noarch,SRPMS,BUILD}
	cp exmh-$(VERSION).tar.gz rpmroot/SOURCES/
	sed 's/VERSION/$(VERSION)/g' < misc/RPM/exmh-conf.patch > rpmroot/SOURCES/exmh-$(VERSION)-conf.patch
	cp misc/RPM/exmh.wmconfig rpmroot/SOURCES/
	sed 's/EXMHVERSION/$(VERSION)/g' < misc/RPM/exmh.spec > rpmroot/SPECS/exmh.spec
	rpm -ba --define "_topdir `pwd`/rpmroot" --buildroot=`pwd`/rpmroot/BUILDROOT rpmroot/SPECS/exmh.spec
	cp rpmroot/RPMS/noarch/exmh-$(VERSION)-1.noarch.rpm .
	cp rpmroot/SRPMS/exmh-$(VERSION)-1.src.rpm .

userrpm:	srctar
	mkdir /tmp/exmhredhat/
	mkdir /tmp/exmhredhat/BUILD
	mkdir /tmp/exmhredhat/RPMS
	mkdir /tmp/exmhredhat/RPMS/noarch
	mkdir /tmp/exmhredhat/SOURCES
	mkdir /tmp/exmhredhat/SPECS
	mkdir /tmp/exmhredhat/SRPMS
	mkdir /tmp/exmhredhat/BUILDROOT
	echo -e "include: /usr/lib/rpm/rpmrc \
	\nmacrofiles: /usr/lib/rpm/macros:/usr/lib/rpm/%{_target}/macros:/etc/rpm/macros:/etc/rpm/%{_target}/macros:~/.rpmmacros:./rpmmacros" > /tmp/exmhredhat//rpmrc
	echo "%_topdir /tmp/exmhredhat" > /tmp/exmhredhat/rpmmacros
	cp exmh-$(VERSION).tar.gz /tmp/exmhredhat/SOURCES/
	sed 's/VERSION/$(VERSION)/g' < misc/RPM/exmh-conf.patch > /tmp/exmhredhat/SOURCES/exmh-$(VERSION)-conf.patch
	cp misc/RPM/exmh.wmconfig /tmp/exmhredhat/SOURCES/
	sed 's/EXMHVERSION/$(VERSION)/g' < misc/RPM/exmh.spec > /tmp/exmhredhat/SPECS/exmh.spec
	(cd /tmp/exmhredhat/ ; rpm -ba --rcfile /tmp/exmhredhat/rpmrc /tmp/exmhredhat/SPECS/exmh.spec)
	cp /tmp/exmhredhat/RPMS/noarch/exmh-$(VERSION)-1.noarch.rpm .
	cp /tmp/exmhredhat/SRPMS/exmh-$(VERSION)-1.src.rpm .
	rm -rf /tmp/exmhredhat

snapuserrpm:
	make userrpm VERSION=$(VERSION)_$(SNAPDATE)

snaprpm:
	make rpm VERSION=$(VERSION)_$(SNAPDATE)

snaptar:
	make srctar VERSION=$(VERSION)_$(SNAPDATE)

version: 
	./PatchVersion $(VERSION) < exmh.install > exmh.install.new
	mv exmh.install.new exmh.install

ftpdist:
	scp exmh-$(VERSION).tar.gz www:~ftp/pub/tcl/exmh
	scp html-$(VERSION).tar.gz www:~ftp/pub/tcl/exmh
	scp exmh.README www:~ftp/pub/tcl/exmh
	scp lib/html/exmh.README.html www:~ftp/pub/tcl/exmh

htmltar:
	echo CVS > lib/html/Tar.exclude
	echo Tar.exclude >> lib/html/Tar.exclude
	cp exmh.CHANGES lib/html/exmh.CHANGES.txt
	(cd lib/html ; tar cfX - ./Tar.exclude . | gzip > ../../html-$(VERSION).tar.gz)

install: srctar ftpdist

