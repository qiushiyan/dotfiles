-- lab.hosts: the other machines' Rex servers, as `rex -S <label>` and `rex do`
-- scripts see them. Each machine declares the others, by ~/.config/machine; a
-- machine with no marker declares none. This is the server's list. The app's
-- sidebar keeps its own, filled by Add Host… (docs/rex.md § Several machines).
-- A stored host with the same label outranks one declared here: `rex hosts
-- remove LABEL` clears it.

local ENDPOINTS = {
  mac = "qiushi-mac.tailf7adf1.ts.net",
  mini = "qiushi-mini-rex.tailf7adf1.ts.net",
  mini2 = "qiushi-mini-2-rex.tailf7adf1.ts.net",
}

local file = io.open(os.getenv("HOME") .. "/.config/machine")
local here = file and file:read("*l")
if file then file:close() end
here = here and here:match("%S+")

if here and ENDPOINTS[here] then
  for label, endpoint in pairs(ENDPOINTS) do
    if label ~= here then rex.host({ label = label, endpoint = endpoint }) end
  end
end
