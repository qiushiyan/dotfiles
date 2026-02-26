#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Focus Zed
# @raycast.mode silent
# @raycast.packageName Focus App

# Optional parameters:
# @raycast.icon 🚀

#!/bin/bash

osascript -e '
tell application "Zed" to activate
tell application "System Events"
    set visible of every process whose visible is true and name is not "Zed" to false
end tell'
