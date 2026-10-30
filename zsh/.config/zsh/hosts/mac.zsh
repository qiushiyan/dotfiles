# The MacBook Pro, the laptop, where ~/.config/machine says `mac`.
# .zshenv sources this last, in every shell. Only what is about being this
# machine belongs here; a tool's setup goes in the shared files behind a check
# for the tool.
#
# No machine badge: the prompt, the tmux status bar and the window title stay
# unmarked here, so a mark always means another machine (hosts/mini.zsh).

# The login ~/.claude holds here; the primary answers to its local part
# (claude.zsh, _claude_primary).
(( $+functions[_claude_primary] )) && _claude_primary qiushi@planlab.ai   # x-qiushi too
