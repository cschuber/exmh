# Create a tar distribution for exmh

VERSION=2.0.3

srctar:
	echo ./CVS > Tar.exclude
	echo ./misc >> Tar.exclude
	echo ./lib/CVS >> Tar.exclude
	echo ./lib/html/CVS >> Tar.exclude
	echo ./Tar.exclude >> Tar.exclude
	echo ./exmh-$(VERSION).tar.gz >> Tar.exclude
	tar cvfX - Tar.exclude . | gzip > exmh-$(VERSION).tar.gz
