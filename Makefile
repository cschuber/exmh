# Create a tar distribution for exmh

VERSION=2.0.3

srctar:
	echo ./CVS > Tar.exclude
	echo ./misc >> Tar.exclude
	echo ./lib/CVS >> Tar.exclude
	echo ./lib/html/CVS >> Tar.exclude
	echo ./lib/html/Tar.exclude >> Tar.exclude
	echo ./Tar.exclude >> Tar.exclude
	echo ./exmh-$(VERSION).tar.gz >> Tar.exclude
	echo ./html-$(VERSION).tar.gz >> Tar.exclude
	tar cvfX - Tar.exclude . | gzip > exmh-$(VERSION).tar.gz

ftpdist:
	scp exmh-$(VERSION).tar.gz www:~ftp/pub/tcl/exmh
	scp html-$(VERSION).tar.gz www:~ftp/pub/tcl/exmh
	scp exmh.README www:~ftp/pub/tcl/exmh
	scp lib/html/exmh.README.html www:~ftp/pub/tcl/exmh

htmltar:
	echo ./CVS > lib/html/Tar.exclude
	echo ./Tar.exclude >> lib/html/Tar.exclude
	(chdir lib/html ; tar cfX - ./Tar.exclude | gzip > ../../html-$(VERSION).tar.gz)

