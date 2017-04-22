#!/bin/bash

# To change the version, first edit the Makefile and
# change the version there, and frob the patterns in
# version.sed.  Then type "make version"

# You still want to add release notes to
# exmh.README and probably the other html files.

for f in  Makefile exmh.README lib/html/index.html lib/html/software.html ;
do
    echo $f
    sed -f version.sed < $f > $f.new
    mv $f $f.old
    mv $f.new $f
    diff $f.old $f
done

echo "Edit lib/html/exmh.README.html by hand"
echo "Use PatchVersion to fix exmh.install"
