#!/usr/bin/wish
#
#   ▐▀▀▌                                  ▐▀▀▌
#   █  ▌                                  █  ▌
# █─█░ ▌─█ _/▀▀▀▌▐▀▀▀\-▄▐▀▀▀\_  _/▀▀▀▌ _/▀▀  ▌
#   █▒░▌_ ▐▒░█  ▌█▒░█  ▌█▒░█  ▌▐▒░█  ▌▐▒░█   ▌
#   █▓▒░ ▌█▓▒░▐ ▌█▓▒░  ▌█▓▒░  ▌█▓▒░▐ ▌█▓▒░░  ▌
#   ▀▀▀▀▀ ▀▀▀▀▀▀ ▀▀▀▀█_▌█_▌▀▀▀ ▀▀▀▀▀▀ ▀▀▀▀▀▀▀
#

package require sqlite3

wm title . "TagPad"
wm geometry . 1500x1000

# confirm before destroying app window if unsaved changes:
wm protocol . WM_DELETE_WINDOW {
    if [confirm] { exit }
}

option add *tearOff 0

set id ""   ;# will hold the currently opened note's id

menu .m
. configure -menu .m
     .m add command -label New  -underline 0 -command newnote
     .m add command -label Save -underline 0 -command savenote
     .m add command -label Open -underline 0 -command opennote

scrollbar .scroll -command {.note yview}
pack .scroll -side right -fill y
text .note -padx 5pt -pady 5pt -font { Consolas, 11 } -wrap word -yscrollcommand {.scroll set}
pack .note -fill both -expand yes -side left


cd $env(HOME)

if ![file exists .tagpad.db] {

    set reply [tk_dialog .dia \
        "No database" \
        "Could not find necessary database file in your home directory. This is normal during first-time execution. Create it now?" \
        info 0 Yes No]

    if {$reply == 0} {
        sqlite3 db .tagpad.db
        db eval {CREATE TABLE notes(id INTEGER PRIMARY KEY AUTOINCREMENT, note TEXT)}
        db eval {CREATE TABLE tags(
                    name TEXT,
                    notesid INTEGER,
                    FOREIGN KEY (notesid) REFERENCES notes(id),
                    PRIMARY KEY (name, notesid)
                )}
        db close
        focus -force . ;# Windows quirk
    } else {
      exit;
    }
}

focus -force . ;# Windows quirk

bind . <Alt-x> quit

proc newnote {} {
    if [confirm] {
        .note delete 1.0 end
        .note edit modified false
        set ::id ""
    }
}

proc savenote {} {
    if {[.note get 1.0 {end -1 chars}] eq ""} { return }
    set note [.note get 1.0 {end -1 chars}]
    sqlite3 db .tagpad.db

    if {$::id == ""} { ;# if no id is given to the note it is not yet saved
        db eval {INSERT INTO notes(note) VALUES($note)}
        set ::id [db last_insert_rowid]
    } else {
        db eval {UPDATE notes SET note=$note WHERE id=$::id}
    }

    # find all tags in $note and insert them into tags table if they do not exist
    set tagtuples [regexp -all -inline {#([^\s]+)} $note]
    foreach {discard keep} $tagtuples { lappend tags $keep }
    foreach tag $tags {
        db eval {INSERT OR IGNORE INTO tags(name, notesid) VALUES ($tag, $::id)}
    }
    
    # find if there are tags in the database linked to our note, that are no longer in our note and delete them
    set dbtags [db eval {SELECT name FROM tags WHERE notesid=$::id}]
    foreach tag $dbtags {
        if {$tag ni $tags} {
            db eval {DELETE FROM tags WHERE name=$tag AND notesid=$::id}
        }
    }
    
    # If all is well:
    .note edit modified false
    db close
}

proc opennote {} {
    if [confirm] {
        toplevel  .opennote -padx 5pt -pady 5pt
        wm state  .opennote [wm state .]
        frame     .opennote.top
        pack      .opennote.top -fill x
        label     .opennote.top.lab -text "Seperate tags by spaces. Exclude pound signs."
        pack      .opennote.top.lab -anchor w
        entry     .opennote.top.searchtags
        pack      .opennote.top.searchtags -side left -fill x -expand yes
        button    .opennote.top.searchnotes -text "Search" -command searchnotes
        pack      .opennote.top.searchnotes -side right
        bind      .opennote.top.searchtags <Return> {.opennote.top.searchnotes invoke}
        frame     .opennote.middle 
        pack      .opennote.middle -fill both -expand yes
        scrollbar .opennote.middle.scroll -command {.opennote.middle.results yview}
        pack      .opennote.middle.scroll -side right -fill y
        listbox   .opennote.middle.results -listvariable notes -yscrollcommand {.opennote.middle.scroll set}
        pack      .opennote.middle.results -fill both -expand yes
        bind      .opennote.middle.results <Return> {.opennote.bottom.open invoke}
        frame     .opennote.bottom
        pack      .opennote.bottom -fill x
        button    .opennote.bottom.open -text "Open" -command loadnote
        pack      .opennote.bottom.open -side bottom -anchor e
        focus -force .opennote ;# Windows quirk
    }

    proc searchnotes {} {
        upvar notes notes ids ids
        set notes ""
        set tags [split [.opennote.top.searchtags get]]
        #get all note ids from database that are linked to by all the $tags
        sqlite3 db .tagpad.db

        # construct query
        set query {SELECT id, substr(note,1,140) FROM notes WHERE}
        for {set i 0} {$i < [llength $tags]} {incr i} {
            append query " id IN (SELECT notesid FROM tags WHERE name='[lindex $tags $i]')"
            if { $i != [expr [llength $tags] - 1]} { append query " AND" }
        }
        #puts $query ;# TODO: remove
        
        # execute
        set tuples [db eval $query]
        #puts $tuples ;# TODO: remove
        set ids {}
        set notes {}
        foreach {id note} $tuples {
            lappend ids $id
            lappend notes [regsub -all {\n} $note { }]
        }
        #puts $ids ;# TODO: remove
        #puts $notes ;# TODO: remove
        
        db close
    }
    proc loadnote {} {
        upvar ids ids
        sqlite3 db .tagpad.db
        set row [db eval "SELECT id, note FROM notes WHERE id=[lindex $ids [.opennote.middle.results curselection]]"]
        db close
        set ::id [lindex $row 0]
        .note delete 1.0 end
        .note insert 1.0 [lindex $row 1]
        .note edit modified false
        destroy .opennote
    }
}

proc quit {} {
    if [confirm] exit
}

proc confirm {} {
    if [.note edit modified] {
        set reply [tk_dialog .confirm "Discarding changes" "Unsaved changes detected. Proceed anyway?" question 0 Yes No]
        if {$reply == 0} {
            return 1
        } else {
            return 0
        }
    }
    return 1
}
