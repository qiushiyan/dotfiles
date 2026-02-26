#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Zen Mode
# @raycast.mode silent
# @raycast.packageName Focus App

# Optional parameters:
# @raycast.icon 🧘

osascript -e '
tell application "System Events"
    set frontApp to name of first application process whose frontmost is true
    set visible of every process whose visible is true and name is not frontApp to false
end tell'
