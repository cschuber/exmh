This is the start of a script that lets you use netscape's mailto: links
with exmh.  It could be extended quite a bit, and is pretty rough right now.  

here is the basic instructions:

- install muttzilla, http://www3.telus.net/brian_winters/mutt/ 
- put comp.pl somewhere in your path, make the changes to the paths at the
  top of the script
- I use the following for my .muttzillarc:

mailscript=mzmail.sh
mailterm=None
mailargs=mutt
mailprog=comp.pl

Comments and questions: Scott Lipcon, slipcon@mercea.net

