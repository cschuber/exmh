# Create a tar distribution for exmh

# Remember to update exmh.install when changing version numbers.

VERSION=2.1.2

srctar: version htmltar
	echo ./CVS > Tar.exclude
	echo ./lib/CVS >> Tar.exclude
	echo ./misc/CVS >> Tar.exclude
	echo ./misc/RPM/CVS >> Tar.exclude
	echo ./lib/html/CVS >> Tar.exclude
	echo ./lib/html/Tar.exclude >> Tar.exclude
	echo ./.exmhinstall >> Tar.exclude
	echo ./Tar.exclude >> Tar.exclude
	echo ./html-$(VERSION).tar.gz >> Tar.exclude
	echo ./exmh-$(VERSION).tar.gz >> Tar.exclude
	rm -rf /tmp/exmh-$(VERSION)
	mkdir /tmp/exmh-$(VERSION)
	tar cvfX - Tar.exclude . | (cd /tmp/exmh-$(VERSION) ; tar xf -)
	(cd /tmp ; tar cf - exmh-$(VERSION) | gzip > /tmp/exmh-$(VERSION).tar.gz)
	cp /tmp/exmh-$(VERSION).tar.gz .

clean:
	rm -f ./Tar.exclude
	rm -f ./exmh-$(VERSION).tar.gz
	rm -f ./html-$(VERSION).tar.gz
	rm -f ./exmh-$(VERSION)-1.noarch.rpm
	rm -f ./exmh-$(VERSION)-1.src.rpm

rpm:	srctar
	cp exmh-$(VERSION).tar.gz /usr/src/redhat/SOURCES/
	cp misc/RPM/exmh-$(VERSION)-conf.patch /usr/src/redhat/SOURCES/
	cp misc/RPM/exmh.wmconfig /usr/src/redhat/SOURCES/
	cp misc/RPM/exmh.spec /usr/src/redhat/SPECS/
	(cd /usr/src/redhat/SPECS/ ; rpm -ba exmh.spec)
	cp /usr/src/redhat/RPMS/noarch/exmh-$(VERSION)-1.noarch.rpm .
	cp /usr/src/redhat/SRPMS/exmh-$(VERSION)-1.src.rpm .


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

