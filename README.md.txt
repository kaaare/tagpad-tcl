TagPad

------

A (very) minimal application for storing and finding notes, based on a tagging system. In other words: Windows Notepad but with tags.


When saving a note, tags are automatically identified from words in the text that start with a pund-sign `#`, and added to the database. Also, any tags found in the database but no longer found in the note, is removed from the database.


Notes can have any number of tags, and searches can be made by specifying any combination of space-separated tags:


> eggdrop quizbot bugfix

To run `tagpad.tcl` you need TCL/Tk, which is usually preinstalled on Mac and Linux. An excellent Windows version is freely available from [ActiveState]("http://www.activestate.com/tcl]ActiveState).


During the first start-up, the application creates a file named `.tagpad.db` in the current user's home directory. This is an SQLite database file containing the application's notes and tags.


`~/.tagpad.db` is the file you might want to backup or move between computers.
