# Stubs for routines that are in WebTk but not used here.

proc dputs {args} {
    return
}
proc Input_Edit {args} {
    return 0	;# never in edit mode
}
proc Input_IsDirty {args} {
    return 0
}
proc Input_Mode {args} {
    return 0
}
proc Input_Adjust {args} {
    return 0
}
proc Undo_Reset {args} {
    return
}
proc Undo_Record {args} {
    return
}
proc Undo_Mark {args} {
    return
}
proc Undo_Init {args} {
    return
}
proc Form_Reset {win} {
    upvar #0 HM$win var
    set var(S_formid) 0
    return
}
proc Embed_Reset {args} {
    return
}
proc Edit_Reset {args} {
    return
}
proc Input_Reset {args} {
    return
}
proc StatusLabel {args} {
    return .bogus
}
proc StatusLazy {args} {
    return
}
proc Mark_ReadTags {args} {
    return
}
proc Mark_Current {args} {
    return current
}
proc MarkUndefined {args} {
    return 
}
proc Toolbar_Update {args} {
    return
}
proc WinHistoryAdd {args} {
    return
}
proc HMmark {args} {
    return
}
proc UrlEditLink {args} {
}
proc Stderr {args} {
    catch {puts stderr [join $args " "]}
}
