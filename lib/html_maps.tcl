# maps.tcl --
#	This file defines tables (i.e., maps) that drive the
#	user interface and editting engine.
#
#	Note: the term "HTML tag" refers to an element of HTML markup
#	such as <p> or <strong>.  An unqualified "tag" usually refers
#	to a tag in the Tk text widget, which applies to a range of text.
#

proc Map_Init {} {

    # The Node map identifies HTML-tags that define nodes (i.e. paragraphs) in
    # the document.  Each node is labeled with a Tk text tag that identifies
    # the type and extent of the node.  The value of the map really isn't used,
    # instead just the existence of map elements is tested.
    global NodeMap
    array set NodeMap {
	div		/div
	p		/p
	h1		/h1
	h2		/h2
	h3		/h3
	h4		/h4
	h5		/h5
	h6		/h6
	blockquote /blockquote
    } 

    global StructureMap
    array set StructureMap {
	pre		/pre
	applet	{helps for output sorting}
	form	ditto
	frame	-
    }

    # The SingletonMap defines HTML-tags that usually occur in isolation.
    # They result in a text mark at their location.
    global SingletonMap
    array set SingletonMap {
	    br		-
	    hr		-
	    input	-
	    img		-
	    li		-
	    dd		-
	    dt		-
	    base	-
	    x-insert	-
	    param	-
	    embed	-
	    webtk	-
    }
    # This is used to tweak sorting for list item tags
    # They sort after open list tags
    global ListSingletonMap
    array set ListSingletonMap {
	li	-
	dd	-
	dt	-
    }
    # These singletons sort before anything
    global HighSingletonMap
    array set HighSingletonMap {
	param -
	x-insert -
    }
    # The rest of the singletons sort after all other tags
    
    # The Break map identifies HTML-tags that require newlines.
    # br is special because it can cause multiple newlines.
    global BreakMap
    array set BreakMap {
	hr		-
	li		-
	dt		-
	dd		-
	pre		/pre
	p		/p
	div		/div
	h1		/h1
	h2		/h2
	h3		/h3
	h4		/h4
	h5		/h5
	h6		/h6
	blockquote /blockquote
	ol		-
	ul		-
	dl		-
	menu	-
	dir		-
	form	-
    }

    # The IgnoreMap defines HTML-tags that need neither a mark or a tag.
    global IgnoreMap
    array set IgnoreMap {
	x-insert {pseudo-tag used to track the insert cursor}
    
	{}		{Null tag can arise during cut/paste}
	{/}		{End-null tag}
    
	hmstart	{All the head-related tags are saved elsewhere.  See head.tcl}
	html	{}
	/html	{}
	head	{}
	/head	{}
	body	{}
	/body	{}
	title	{}
	/title	{}
	meta	{}
	!doctype	{}
	link	{}
	option	{this are hidden behind a listbox and output specially}
    }
    
    # Style-type HTML tags result in text-tags that label a range of text.
    # The value of the map appears in the Style menu.
    global StyleMap StyleList
    array set StyleMap {
	b		Bold
	i		Italic
	u		UnderLine
	address	Address
	big	Big
	cite	Citation
	code	Code
	dfn		Definition
	em		Emphasis
	kbd		Keyboard
	samp		Sample
	strong		Strong
	small		Small
	tt		Teletype
	var		Variable
	center		Center
	strike		StrikeThrough
	sup		Superscript
	sub		Subscript
	a		{not in a menu - only for PlainText and RemoveStyle}
	font		{not in a menu - only for PlainText and RemoveStyle}
    }
    # These sort at the same level as text styles,
    # but should not be affected by RemoveStyle
    array set FormItemMap {
	textarea {for output sorting}
	select {for output sorting}
    }
    # Order for the Style menu
    set StyleList {
	b i u address cite code dfn em kbd samp strong tt var center big small strike sub sup
    }
    
    # The ParaMap defines the Paragraph menu.
    # Note - this is hacked in window.tcl to include other stuff, too
    global ParaMap ParaList
    array set ParaMap {
	p		Basic
	div		{not in menu this way - see window.tcl}
	h1		"Heading 1"
	h2		"Heading 2"
	h3		"Heading 3"
	h4		"Heading 4"
	h5		"Heading 5"
	h6		"Heading 6"
	blockquote	BlockQuote
	pre		Preformatted
    }
    set ParaList {
	p h1 h2 h3 h4 h5 h6 blockquote pre
    }
    
    # The ListMap and ListList define the List menu
    global ListMap ListList
    array set ListMap {
	ul		Unordered
	ol		Ordered
	dl		Definition
	menu	Menu
	dir		Directory
    }
    set ListList {
	ul ol dl menu dir
    }
    
    # The UnPMap is used to turn of <p> tags that are unclosed

    global UnPMap
    array set UnPMap [array get NodeMap]
    array set UnPMap [array get ListMap]
    array set UnPMap [array get ListSingletonMap]
    array set UnPMap [array get StructureMap]
    array set UnPMap {
	/hmstart	{This is a trick to get unclosed nodes handled}
    }

    # TableMap is defined in the experimental table.tcl (optionally)
    global TableMap

    # The AllMap records state about every known tag
    global KnownMap
    foreach map {NodeMap StructureMap SingletonMap ListSingletonMap
	    HighSingletonMap BreakMap IgnoreMap StyleMap FormItemMap
	    ParaMap ListMap TableMap} {
	array set KnownMap [array get $map]
    }

    # SortMap is used to sort HTML tags that occur at the same location.
    # It determines the way tags nest in output.
    # param < /strong < /h2 < /ol < /form < form < ol < li < h2 < strong < img
    # See OutputSortHtags

    global SortMap

    set order 1
    foreach name [array names HighSingletonMap] {
	set SortMap($name) $order
    }
    incr order
    foreach style [array names StyleMap] {
	set SortMap(/$style) $order
    }
    # Same rank as Style
    foreach formitem [array names FormItemMap] {
	set SortMap(/$formitem) $order
    }
    incr order
    foreach node [array names NodeMap] {
	set SortMap(/$node) $order
    }
    incr order
    foreach list [array names ListMap] {
	set SortMap(/$list) $order
    }
    global SortListEnd
    set SortListEnd $order
    
    incr order
    foreach name [array names TableMap] {
	set SortMap(/$name) $order
    }
    incr order
    foreach name [array names StructureMap] {
	set SortMap(/$name) $order
    }
    incr order
    foreach name [array names StructureMap] {
	set SortMap($name) $order
    }
    incr order
    foreach name [array names TableMap] {
	set SortMap($name) $order
    }
    
    incr order
    foreach list [array names ListMap] {
	set SortMap($list) $order
    }
    global SortList
    set SortList $order
    incr order
    foreach name [array names ListSingletonMap] {
	set SortMap($name) $order
    }
    incr order
    foreach node [array names NodeMap] {
	set SortMap($node) $order
    }
    incr order
    foreach style [array names StyleMap] {
	set SortMap($style) $order
    }
    # Same rank as Style
    foreach formitem [array names FormItemMap] {
	set SortMap($formitem) $order
    }
    incr order
    foreach name [array names SingletonMap] {
	if {![info exists HighSingletonMap($name)] \
		&& ![info exists ListSingletonMap($name)]} {
	    set SortMap($name) $order
	}
    }
    global SortUnknown
    set SortUnknown [incr order]
}
