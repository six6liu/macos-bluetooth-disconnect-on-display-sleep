-- display_bt_toggle.applescript
-- Menu bar wrapper for the display-bt-watcher shell script.
-- Compiled with osacompile into Display BT Toggle.app.
--
-- See README.md for details.

use framework "AppKit"
use scripting additions

on run
    -- Stop any previous instance cleanly (idempotent).
    do shell script "pkill -f 'log stream.*com.apple.SkyLight' 2>/dev/null; pkill -f 'display-bt-watcher' 2>/dev/null; sleep 1; true"

    -- Launch the watcher in the background.
    set appPath to (path to me)
    set scriptPath to POSIX path of (appPath as string) & "Contents/Resources/display-bt-watcher.sh"
    do shell script "nohup '" & scriptPath & "' > /dev/null 2>&1 &"

    -- Build the menu bar item.
    set statusBar to current application's NSStatusBar's systemStatusBar()
    set theItem to statusBar's statusItemWithLength:-1.0
    theItem's setTitle:"📺"
    theItem's setToolTip:"macos-bluetooth-disconnect-on-display-sleep"

    set theMenu to current application's NSMenu's alloc()'s init()

    set statusMenuItem to current application's NSMenuItem's alloc()'s initWithTitle:"Listening for display sleep" action:(missing value) keyEquivalent:""
    statusMenuItem's setEnabled:false
    theMenu's addItem:statusMenuItem

    theMenu's addItem:(current application's NSMenuItem's separatorItem())

    set quitItem to current application's NSMenuItem's alloc()'s initWithTitle:"Quit" action:"quitAction:" keyEquivalent:"q"
    quitItem's setTarget:me
    theMenu's addItem:quitItem

    theItem's setMenu:theMenu
end run

on quitAction:sender
    do shell script "pkill -f 'log stream.*com.apple.SkyLight' 2>/dev/null; pkill -f 'display-bt-watcher' 2>/dev/null; true"
    current application's NSApp's terminate:(missing value)
end quitAction:

on idle
    return 60
end idle
