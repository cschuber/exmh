#!/bin/csh
foreach f ( Makefile exmh.README exmh.install lib/html/index.html lib/html/software.html lib/html/exmh.README.html )
    echo $f
    sed -f version.sed < $f > $f.new
    mv $f $f.old
    mv $f.new $f
    diff $f.old $f
end
