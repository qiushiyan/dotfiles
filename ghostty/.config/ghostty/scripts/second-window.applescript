-- ctrl+` upsert, second half. Karabiner passes ctrl+` through to Ghostty,
-- whose goto_window:next toggles when a second window or tab exists, then
-- runs this script. With a lone tab in a lone window, goto_window:next has
-- nothing to reach, so open the second window here and center it on its
-- screen. Its size comes from window-width/window-height in the config.
use framework "AppKit"
use scripting additions

tell application "Ghostty"
	set tabCount to 0
	repeat with w in windows
		set tabCount to tabCount + (count of tabs of w)
	end repeat
	if tabCount ≥ 2 then return
	new window
end tell

-- Ghostty's dictionary has no window bounds, so move it through
-- System Events (Accessibility). The new window is frontmost.
tell application "System Events" to tell process "Ghostty"
	set {winX, winY} to position of window 1
	set {winW, winH} to size of window 1
end tell

-- NSScreen frames are bottom-left origin; System Events uses top-left
-- origin anchored at the primary screen. Center on the visible area (below
-- the menu bar, beside the Dock) of the screen the window opened on.
set screens to current application's NSScreen's screens() as list
set primaryH to item 2 of item 2 of ((item 1 of screens)'s frame())
set midX to winX + winW / 2
set midY to winY + winH / 2
repeat with s in screens
	set {{fx, fy}, {fw, fh}} to s's visibleFrame()
	set topY to primaryH - (fy + fh)
	if midX ≥ fx and midX < fx + fw and midY ≥ topY and midY < topY + fh then
		tell application "System Events" to tell process "Ghostty" to ¬
			set position of window 1 to {round (fx + (fw - winW) / 2), round (topY + (fh - winH) / 2)}
		exit repeat
	end if
end repeat
