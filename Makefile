# Create a tar distribution for exmh

# Remember to update exmh.install when changing version numbers.

VERSION=2.6
SNAPDATE=`/bin/date +%Y%m%d`

srctar: version htmltar
	echo ./CVS > Tar.exclude
	echo ./lib/CVS >> Tar.exclude
	echo ./misc/CVS >> Tar.exclude
	echo ./misc/RPM/CVS >> Tar.exclude
	echo ./lib/html/CVS >> Tar.exclude
	echo ./lib/bitmaps/CVS >> Tar.exclude
	echo ./lib/html/Tar.exclude >> Tar.exclude
	echo ./.exmhinstall >> Tar.exclude
	echo ./Tar.exclude >> Tar.exclude
	echo ./html-\*.tar.gz >> Tar.exclude
	echo ./exmh-\*.tar.gz >> Tar.exclude
	echo ./exmh-\*.src.rpm >> Tar.exclude
	echo ./exmh-\*.noarch.rpm >> Tar.exclude
	echo ./rpmroot >> Tar.exclude
	echo ./exmh-$(VERSION) >> Tar.exclude
	echo ./exmh-$(VERSION).tar.gz >> Tar.exclude
	echo ./html-$(VERSION).tar.gz >> Tar.exclude
	rm -rf ./exmh-$(VERSION)
	mkdir ./exmh-$(VERSION)
	tar cvfX - Tar.exclude . | (cd ./exmh-$(VERSION) ; tar xf -)
	(tar cf - exmh-$(VERSION) | gzip > ./exmh-$(VERSION).tar.gz)
	rm -rf ./exmh-$(VERSION)

clean:
	rm -f ./Tar.exclude
	rm -f ./lib/html/Tar.exclude
	rm -f ./exmh-*.tar.gz
	rm -f ./html-*.tar.gz
	rm -f ./exmh-*.noarch.rpm
	rm -f ./exmh-*.src.rpm
	rm -f ./lib/html/exmh.CHANGES.txt
	rm -rf ./rpmroot/
	rm -rf ./exmh-$(VERSION)

rpm:	srctar
	mkdir -p rpmroot/{SOURCES,SPECS,BUILDROOT,RPMS/noarch,SRPMS,BUILD}
	cp exmh-$(VERSION).tar.gz rpmroot/SOURCES/
	sed 's/VERSION/$(VERSION)/g' < misc/RPM/exmh-conf.patch > rpmroot/SOURCES/exmh-$(VERSION)-conf.patch
	cp misc/RPM/exmh.wmconfig rpmroot/SOURCES/
	cp misc/RPM/exmh.desktop rpmroot/SOURCES/
	sed 's/EXMHVERSION/$(VERSION)/g' < misc/RPM/exmh.spec > rpmroot/SPECS/exmh.spec
	rpmbuild -ba --define "_topdir `pwd`/rpmroot" --buildroot `pwd`/rpmroot/BUILDROOT rpmroot/SPECS/exmh.spec
	cp rpmroot/RPMS/noarch/exmh-$(VERSION)-?.noarch.rpm .
	cp rpmroot/RPMS/noarch/exmh-misc-$(VERSION)-?.noarch.rpm .
	cp rpmroot/SRPMS/exmh-$(VERSION)-?.src.rpm .

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

