# manage the image file cache.

proc Cache_Init {} {
    global cache cachesize WebTk
    set max [expr 1024 * 1024 * 2]
    catch {set max $cachesize(max)}
    catch {unset cachesize}
    set cachesize(total) 0
    set cachesize(max) $max
    CacheMkDir $WebTk(cache)
    foreach u [array names cache] {
	Cache_SetFile $u $cache($u)
    }
}

proc !Cache_Preferences {win} {
    global cachesize WebTk imagecachesize
    set current 0
    catch {set current [expr $cachesize(total) / 1024]}
    set max [expr $cachesize(max)/1024]
    DialogEntry $win .cache "
Images are cached in two ways.
1) A directory holds data between uses of WebTk.  You
can choose the location and the max size of this image cache.
Increasing this parameter increases disk space usage.
The current size is $current Kbytes out of $max Kbytes.
2) In-memory images are retained after you leave a page.
You can control how many images are retained.  Increasing
this parameter increases memory use.  A setting of zero 
minimizes memory use.
" CachePrefOK [list [list Directory $WebTk(cache)] \
		    [list "Max Kbytes" $max] \
		    [list "Image Count" $imagecachesize] \
	    ]
}
proc !CachePrefOK {list} {
    global cachesize WebTk imagecachesize
    array set t $list
    set WebTk(cache) $t(Directory)
    catch {set cachesize(max) [expr $t(Max\ Kbytes) * 1024]}
    catch {set imagecachesize [expr $t(Image\ Count)]}
    if {$cachesize(max) < 0} {
	set cachesize(max) 0
    }
    if {$imagecachesize < 0} {
	set imagecachesize 0	;# Enforced when a new page is displayed
    }
    while {$cachesize(total) > $cachesize(max)} {
	CacheDeleteOne
    }
    CheckPoint
}
proc CachePrefTrace {} {
    global cachesize WebTk imagecachesize
    if {$cachesize(max) < 0} {
	set cachesize(max) 0
    }
    if {$imagecachesize < 0} {
	set imagecachesize 0	;# Enforced when a new page is displayed
    }
    while {$cachesize(total) > $cachesize(max)} {
	CacheDeleteOne
    }
}
proc Cache_Cleanup {} {
    global cache

    foreach url [array names cache] {
	File_Delete $cache($url)
    }
}

proc Cache_NewFile {url} {
    global cache WebTk
    if ![info exists cache($url)] {
	set hash 8251
	foreach c [split $url {}] {
	    scan $c %c x
	    set hash [expr {($hash << 5) ^ $x}]
	}
	set hash [expr {$hash & 0x7FFFFFFF}]
	return [file join $WebTk(cache) [format %x $hash][file extension $url]]
    } else {
	return $cache($url)
    }
}

# If a name is in the cache, but no cache size, then the
# cache has not been fully loaded.

proc Cache_GetFile {url} {
    global cache
    if [info exists cache($url)] {
	return $cache($url)
    } else {
	return {}
    }
}

proc Cache_SetFile {url file} {
    global cache cachesize
    set old 0
    catch {set old $cachesize($file)}
    if [catch {
	# File may no longer exist
	set cachesize($file) [file size $file]
	incr cachesize(total) [expr $cachesize($file)-$old]
	set cache($url) $file
	Exmh_Debug "cache $file $url"
	while {$cachesize(total) > $cachesize(max)} {
	    CacheDeleteOne
	}
    }] {
	catch {unset cachesize($file)}
	catch {unset cache($url)}
	incr cachesize(total) -$old
	if {$cachesize(total) < 0} {
	    set cachesize(total) 0
	}
    }
}
proc CacheDeleteOne {} {
    global cache cachesize
    set urls [array names cache]	;# Random hash
    set url [lindex $urls 0]
    set file $cache($url)
    File_Delete $file
    catch {unset cache($url)}
    catch {incr cachesize(total) -$cachesize($file)}
    catch {unset cachesize($file)}
    if {[llength $urls] <= 1} {
	set cachesize(total) 0
    }
}
proc CacheMkDir {dir} {
    global tk_version
    if {$tk_version < 4.2} {
	set tail [file tail $dir]
	set dir [file dirname $dir]
	set dir [glob -nocomplain $dir]/$tail
	catch {mkdir $dir}
	catch {exec mkdir $dir}
    } else {
	file mkdir $dir
    }
}
Cache_Init

