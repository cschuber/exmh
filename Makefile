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

rpm:	srctar
	cp exmh-$(VERSION).tar.gz /usr/src/redhat/SOURCES/
	sed 's/VERSION/$(VERSION)/g' < misc/RPM/exmh-conf.patch > /usr/src/redhat/SOURCES/exmh-$(VERSION)-conf.patch
	cp misc/RPM/exmh.wmconfig /usr/src/redhat/SOURCES/
	sed 's/EXMHVERSION/$(VERSION)/g' < misc/RPM/exmh.spec > /usr/src/redhat/SPECS/exmh.spec
	(cd /usr/src/redhat/SPECS/ ; rpm -ba exmh.spec)
	cp /usr/src/redhat/RPMS/noarch/exmh-$(VERSION)-1.noarch.rpm .
	cp /usr/src/redhat/SRPMS/exmh-$(VERSION)-1.src.rpm .

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

