-- rex do ~/.config/rex/scripts/theme.lua [include=PATH]
--
-- Push the terminal theme theme-set selected to every Rex terminal. The
-- palette comes from the Ghostty include theme-set writes, so Rex follows the
-- same per-theme choice as Ghostty without a palette of its own.

package.path = os.getenv("HOME") .. "/.config/rex/lua/?.lua;" .. package.path
return require("rexkit").apply_theme(rex.args.include)
