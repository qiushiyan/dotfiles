-- ctrl+` upsert, second half. Karabiner passes ctrl+` through to Ghostty,
-- whose goto_window:next toggles when a second window or tab exists, then
-- runs this script. With a lone tab in a lone window, goto_window:next has
-- nothing to reach, so open the second window here.
tell application "Ghostty"
	set tabCount to 0
	repeat with w in windows
		set tabCount to tabCount + (count of tabs of w)
	end repeat
	if tabCount < 2 then new window
end tell
