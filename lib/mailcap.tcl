# mailcap parsing suite
# by Marc VanHeyningen <mvanheyn@cs.indiana.edu>
# May 1994
# Use and redistribute freely
# 
# This is a package of routines in Tcl for handling mailcap files for use in
# manipulating MIME objects.  It was written with incorporation into Exmh
# and maybe TkWWW in mind, but could work for any Tcl program that deals
# with MIME objects.  If you incorporate it into something and find it works
# well, I'd be interested in hearing about it.
# 
# This package attempts to be faithful to the specification for both
# MIME (RFC 1521) and mailcap files (RFC 1524; this code actually
# includes some features from a later draft.)  The only real limitation
# is that it doesn't support the %F semantics from appendix A; however,
# it does support %M, which is arguably superior anyway.
# 
# SIMPLE USE:
# Obviously, load this file.  You may wish to change the variable
# "mailcap_default_path" to include some specific per-application
# mailcap file.
# 
# The procedure mailcap_load will read in all the rules, attempting to
# prune down the number of rules to store by evaluating test conditions
# ahead of time where possible.  The rules are stored in the global
# associative array mailcap_rules; subsequent changes in the mailcap
# file will not take effect unless mailcap_load is invoked again.
# 
# The procedure mailcap_parse_content_type will do most of the parsing
# of the MIME Content-Type header for you.  Your program should pull off
# the "Content-Type:" label and put together line continuations per RFC
# 822, but mailcap will do the MIME-specific parsing.
# mailcap_parse_content_type takes two arguments; the entire header (minus the
# label) and the name of an associative array into which the parameters
# will be placed.  The procedure returns the content type and subtype.
# 
# The primary procedure is mailcap_getrule; it is how you extract an
# appropriate rule from the mailcap file.  It takes as arguments:
# 
#  - The content-type (as returned by mailcap_parse_content_type)
#  - The name of the array of parameters (from mailcap_parse_content_type)
#  - The method to do (e.g. "compose", "print", "description",
#    "x11-bitmap".  The empty string finds the view command.)
#  - The name of an array to store additional fields from the mailcap
#    entry in.
#  - The temporary filename containing the unencoded body
#  - (optional) A list of pairs of content-types and filenames of the
#    body-parts of a multipart message, for use in %F substitution (not
#    often used, ignore freely)
#  - (optional) A list of pairs of filenames of headers and bodies of
#    the body-parts of a multipart message, for use in %M substitution
#    (not often used, ignore freely)
# 
# SIMPLE EXAMPLE :
#  The following line is from a mailcap file:
#   text/richtext; richtext %s; copiousoutput
#  
# % source mailcap.tcl
# % mailcap_load
# % set ct [mailcap_parse_content_type {text/richtext; charset = "US-ASCII"} p]
# text/richtext
# % set p(charset)
# US-ASCII
# % set cmd [mailcap_getrule $ct p "" at "/tmp/blah.1234"]
# richtext /tmp/blah.1234
# % info exists at(copiousoutput)
# 1
# % info exists at(needsterminal)
# 0
# 
# SIMPLE USE IN A MAILER:
# 
#  ... somehow set up headers ...
#  
#  set content_type [mailcap_parse_content_type $header(content-type) \
#                     content_params];
#  
#  ... attempt to display the content type using built in procedures ...
#  ... store content in file $body_filename ...
# 
#  set cmd [mailcap_getrule $content_type content_params "" cmd_atribs \
#            $body_filename];
#  if [info exists cmd_atribs(needsterminal)] {
#    exec "xterm" "-e" "sh" "-c" $cmd;
#  } {if [info exists cmd_atribs(copiousoutput)] {
#    exec "sh" "-c" "$cmd | xless";
#  } {
#    exec "sh" "-c" $cmd;
#  }
#  ...
# 
# Obviously a real mailer would do some more sophisticated things, such
# as use "catch" in appropriate places to handle failures of various
# rule lookups.
# 
# Note that the "nametemplate" field may be useful in generating
# temporary files with descriptive names:
# 
# % mailcap_getrule "image/gif" bogus "nametemplate" bogus2 "/tmp/f1234"
# /tmp/f1234.gif
# 
# For composing agents, this functionality may be reversed with the
# procedure mailcap_guess_content_type.  Note that this means using
# mailcap information in a manner it wasn't really intended for, but
# which can be useful.  The results should never be taken as
# authoritative, but may be a useful default in prompting a user what
# the content-type of a file is:
# 
# % mailcap_guess_content_type "/usr/local/neat/writeup.ps"
# application/postscript
# 


proc mailcap_backslash_undo {string} {
  set buffer $string
  regsub -all {\\(.)} $string {\1} buffer;
  return $buffer;
}

proc mailcap_normalize {string} {
  return [string trim [mailcap_backslash_undo $string] " \t"];
}

proc mailcap_normalize_full {string} {
  return [string tolower [mailcap_normalize $string]];
}

proc mailcap_load {} {
  global mailcap_rules mailcap_default env exmh
  catch {unset mailcap_rules};
  if [info exists env(MAILCAPS)] {
      set mailcap_path $env(MAILCAPS)
  } else {
      set mailcap_path $exmh(userLibrary)/user.mailcap:$env(HOME)/.mailcap:$exmh(library)/local.mailcap:$exmh(library)/mailcap/:$mailcap_default
  }
  if [info exists env(METAMAIL_HOME)] {
    append mailcap_path :$env(METAMAIL_HOME)/mailcap
  }

  foreach mailcap_file [split $mailcap_path :] {
    catch {close $fh}
    if {![file exists $mailcap_file] ||
	[file isdirectory $mailcap_file] ||
	[catch {open $mailcap_file} fh]} {
	continue
    }
    set buf [read $fh];
# wrap line continuations together by deleting backslash-newlines
    set subpat "((^|\[^\\\\\])(\\\\\\\\)*)\\\\\n";
    regsub -all "$subpat" $buf {\1} rules;

    set forget_it 0;
    foreach rule [split $rules \n] {
      if [regexp {^([ \t]*)$|^#} $rule] {continue};
      regsub -all {((^|[^\\])(\\\\)*)\;} $rule "\\1\n" fields;
      set field_list [split $fields "\n"];
      set rule_content_type [mailcap_normalize_full [lindex $field_list 0]];
      if [regexp {^(.+)/(.+)$} $rule_content_type bogus rule_content_primary \
          rule_content_secondary] {} {
# handle implicit wildcards
	set rule_content_primary $rule_content_type;
	set rule_content_secondary "*";
      }
      
      set rule_viewer [mailcap_normalize [lindex $field_list 1]];
      set rule_fields {};
      foreach rule_field [lrange $field_list 2 end] {
	if [regexp {^([^=]+)=(.*)$} $rule_field bogus field_name field_value] {
	  set field_name [mailcap_normalize_full $field_name];
          regexp {^\"([^\"]+)\"$} [string trim $field_value] bogus field_value;
	  if {$field_name == "test"} {
	    if [regexp {(^|[^\\])(\\\\)*\%} $field_value] {} {
	      if [catch {exec "sh" "-c" [mailcap_normalize $field_value]}] {
		set forget_it 1;
		break;
	      } {
		continue;
	      }
	    }
	  }
	  lappend rule_fields [list $field_name $field_value];
	} {
          set rule_field [mailcap_normalize_full $rule_field];
          if {$rule_field == "needsx11"} {
            if [info exists env(DISPLAY)] {continue} {
              set forget_it 1;
              break;
            }
          }
	  lappend rule_fields $rule_field;
	}
      }
      if {$forget_it == 1} {
	set forget_it 0;
      } {
	lappend mailcap_rules($rule_content_primary) \
	  [concat [list $rule_content_secondary $rule_viewer] $rule_fields];
      }
    }
  }
}

# Note that quoting parameters is done with single quotes for
# security, so that shell metacharacters should not have
# problematic effects at the shell level.
proc mailcap_quote_param {string} {
  regsub -all "\'" [string trim $string " \t"] "\'\"\'\"\'" buffer;
  # These are also used in regsubs, so protect against specials there, esp &
  regsub -all {[][&*+?()]} $buffer {\\&} buffer
  return "\'$buffer\'";
}

proc mailcap_normalize_command {method string content_type body_filename f_multi_list m_multi_list params} {
  upvar $params p;
  
  set f_multi_files "";
  foreach file_pair $f_multi_list {
    set f_multi_files \
      "$f_multi_files [mailcap_quote_param [lindex $file_pair 0]] [lindex $file_pair 1]";
  }

  set m_multi_files "";
  foreach file_pair $m_multi_list {
    set m_multi_files "$m_multi_files [join $file_pair]";
  }

  set num_parts [llength $f_multi_list];
  if {$num_parts == 0} {set num_parts [llength $m_multi_list]};

  set file_used [expr \
    [regsub -all {((^|[^\\])(\\\\)*)%s} $string "\\1$body_filename" string] + \
    [regsub -all {((^|[^\\])(\\\\)*)%F} $string "\\1$f_multi_files" string] + \
    [regsub -all {((^|[^\\])(\\\\)*)%M} $string "\\1$m_multi_files" string]];

  regsub -all {((^|[^\\])(\\\\)*)%t} $string "\\1$content_type" string;
  regsub -all {((^|[^\\])(\\\\)*)%n} $string "\\1$num_parts" \
       string;

# Note that this will fail with parameters containing the {} characters,
# which is legal but not used and rather bizarre.
  while {[regexp {((^|[^\\])(\\\\)*)%\{([^ \{\}\;]+)\}} "$string" \
           full prelude junk1 junk2 attribute]} {
    if [info exists p($attribute)] {
      regsub $full $string "$prelude[mailcap_quote_param $p($attribute)]" \
        string;
    } {
# instantiate undefined parameters as the empty string
      regsub $full $string "$prelude\'\'" string;
    }
  }
  if {$file_used != 0} {} {
    if {($method == "") || ($method == "print") || ($method == "edit")} {
      set string "($string) < $body_filename";
    } {
      if {($method == "compose") || ($method == "composetyped") || \
          ($method == "edit")} {
        set string "($string) > $body_filename";
      }
    }
  }
  return $string;
}

proc mailcap_parse_content_type {content_type_header parameters} {
  upvar $parameters p;
  regsub -all "\[ \t\n\]" $content_type_header " " content_type_header;
  if ![regexp {^([^;]+)(.*)$} $content_type_header bogus content_type params] {
    return text/plain
  }
  set content_type [string tolower [string trim $content_type " "]];

# ensure space at the end for ease of parsing
  set params "$params ";
  while {[regexp {^[ \;]*([^\;\= ]+) *\= *(.*)$} $params bogus attribute rest]} {
    set attribute [mailcap_normalize_full $attribute];
    if {[string index $rest 0] == "\""} {
      if {[regexp -indices {[^\\](\\\\)*(\")} $rest bogus1 bogus2 quotepos]} {
        set quotepos [lindex $quotepos 0];
        set value [mailcap_backslash_undo [string range $rest 1 \
                                            [expr $quotepos - 1]]];
        set params [string range $rest [expr $quotepos + 1] end];
      } { return -code error "Bad quoted paramater in $params"}
    } {
      if {[regexp -indices {[ \;]} $rest endpos]} {
        set endpos [lindex $endpos 0];
        set value [string range $rest 0 [expr $endpos - 1]];
        set params [string range $rest $endpos end];
      } { return -code error "Bad paramater line $params"}
    }
    set p($attribute) $value;
  }
  return $content_type;
}


proc mailcap_getrule {content_type params method field_array body_filename
  {f_multipart_filenames {}} {m_multipart_filenames {}}} {
  global mailcap_rules env;
  upvar $field_array fa; 
  upvar $params p

  if [regexp {^(.+)/(.+)$} $content_type bogus primary secondary] {} {
# cop-out to handle incorrect but sometimes used primary types only
    set primary $content_type;
    set secondary "*";
  }
  if [info exists mailcap_rules($primary)] {} {
    return -code error "No rules for primary type $primary"
  }

  foreach rule $mailcap_rules($primary) {
    set rule_secondary [lindex $rule 0];
    if {($secondary != $rule_secondary) && ($rule_secondary != "*")} {
      continue;
    }
    set fa() [lindex $rule 1];
# Ignore empty view-commands; note that metamail won't handle this
    if {[string length $fa()] == 0} {unset fa()};
    set forget_it 0;

    foreach field [lrange $rule 2 end] {
      set field_name [lindex $field 0];
      if {$field_name == ""} {continue}
      set field_value [lindex $field 1];
      set fa($field_name) [mailcap_normalize $field_value];
    }

    if [info exists fa($method)] {} {set forget_it 1}
# note we don't test needsx11 here because we did that at load time
    if {($forget_it == 0) && [info exists fa(test)]} {
      set test_cmd [mailcap_normalize_command "test" \
		     $fa(test) $content_type $body_filename \
                     $f_multipart_filenames $m_multipart_filenames p];
      if [catch {exec "sh" "-c" $test_cmd}] {
        set forget_it 1
      }
    }
    if {$forget_it == 1} {
      catch {unset fa};
      continue;
    }

    if [info exists fa($method)] {
      if [catch {mailcap_normalize_command $method $fa($method) \
               $content_type $body_filename $f_multipart_filenames \
               $m_multipart_filenames p} cmd] {} {
        return $cmd;
      }
    }
  }
  if {$method == {}} {
      set method view
  }
  return -code error "Could not find $method rule for $content_type";
}

proc mailcap_guess_content_type {filename} {
  global mailcap_rules;

  foreach primary [array names mailcap_rules] {
    foreach rule $mailcap_rules($primary) {
      set secondary [lindex $rule 0];
      foreach field [lrange $rule 2 end] {
        set field_name [lindex $field 0];
        if {$field_name == "nametemplate"} {
          set field_value [lindex $field 1];
	  if [string match "%s" $field_value] continue
	  regsub -all {([.()?*+|])} $field_value {\\\1} field_value
          regsub {%s} $field_value {.*} field_value;
          if [regexp -nocase "^$field_value\$" $filename] {
            return "$primary/$secondary";
          }
        }
      }
    }
  }
  return -code error "Unable to match $filename with any rules";
}

proc mailcap_checkrule {content_type params method args} {
  global mailcap_rules env;

  if [regexp {^(.+)/(.+)$} $content_type bogus primary secondary] {} {
# cop-out to handle incorrect but sometimes used primary types only
    set primary $content_type;
    set secondary "*";
  }
  if [info exists mailcap_rules($primary)] {} {
    return 0
  }

  foreach rule $mailcap_rules($primary) {
    set rule_secondary [lindex $rule 0];
    if {($secondary != $rule_secondary) && ($rule_secondary != "*")} {
      continue;
    }
    if {$method == {}} {
	return 1	;# Assume a view method is defined
    }

    foreach field [lrange $rule 2 end] {
      set field_name [lindex $field 0];
      if {[string compare $field_name $method] == 0} {
	  return 1
      }
    }
  }
  return 0
}

