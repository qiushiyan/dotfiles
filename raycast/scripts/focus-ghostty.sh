#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Focus Ghostty
# @raycast.mode silent
# @raycast.packageName Focus App

# Optional parameters:
# @raycast.icon 👻

#!/bin/bash

osascript -e '
tell application "Ghostty" to activate
tell application "System Events"
    set visible of every process whose visible is true and name is not "Ghostty" to false
end tell'
