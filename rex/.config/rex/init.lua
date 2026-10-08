-- Rex config. An experiment, not a tmux port: what Rex makes possible for
-- agent work. Lab notebook, findings and open questions:
-- ~/dotfiles/docs/rex.md. Validate with `rex config check`, apply with
-- `rex config reload` (the reload reads the modules below again too).
--
--   lua/rexkit/  the library, shared with the `rex do` scripts and tools:
--                api (calls to a server), agents, layout, host, feedback,
--                shell, state
--   lua/lab/     this config: action (how an action is defined), client
--                (moving the app), one module of actions per domain, and
--                keys, which binds them all

package.path = os.getenv("HOME") .. "/.config/rex/lua/?.lua;" .. package.path

require("lab.agents")
require("lab.tabs")
require("lab.panes")
require("lab.tools")
require("lab.keys")
