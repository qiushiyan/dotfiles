# Terminal theme switcher.
#
# Drives prompt (oh-my-posh), Claude Code statusline, and ls/completion
# colors from a single env var. Sourced from .zshenv via the *.zsh glob,
# so it runs before .zshrc / oh-my-zsh.
#
# Resolution order:
#   1. $TERMINAL_THEME if already set in the environment
#   2. ~/.config/terminal-theme   (single line, e.g. `flexoki_light`)
#   3. flexoki_light              (built-in default)
#
# To switch:
#   echo catppuccin_mocha > ~/.config/terminal-theme   # persistent
#   export TERMINAL_THEME=catppuccin_mocha             # current shell only
#
# Supported themes: flexoki_light, catppuccin_mocha
#
# Notes
# -----
# - We export DISABLE_LS_COLORS=true so oh-my-zsh's theme-and-appearance.zsh
#   leaves LSCOLORS/LS_COLORS alone and we own them here. That also means we
#   set the `ls` alias ourselves (oh-my-zsh would have set `ls -G` on macOS).
# - LSCOLORS letter codes (BSD ls) and LS_COLORS numeric codes (GNU ls + zsh
#   completion) both index into the terminal's 16-color palette, which is set
#   by Ghostty's theme. So in principle a single string adapts across themes —
#   but we still differentiate per-theme to control bold-vs-plain (bright dirs
#   look right on dark bg, less so on cream).

if [[ -z "$TERMINAL_THEME" && -r "$HOME/.config/terminal-theme" ]]; then
    TERMINAL_THEME=$(tr -d '[:space:]' < "$HOME/.config/terminal-theme")
fi
: "${TERMINAL_THEME:=flexoki_light}"
export TERMINAL_THEME

export DISABLE_LS_COLORS=true

case "$TERMINAL_THEME" in
    flexoki_light)
        # Cream bg: prefer non-bold dark hues. Letters: a-h = ANSI 30-37,
        # A-H = bold variants, x = default. 11 (fg,bg) pairs: dir, link,
        # socket, pipe, exec, block, char, suid, sgid, sticky+ow, ow.
        # dir=blue, link=magenta, socket=green, pipe=yellow, exec=red.
        export LSCOLORS='exfxcxdxbxegedabagacad'
        export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
        ;;
    catppuccin_mocha)
        # Dark bg: bold/bright dir for emphasis. Matches oh-my-zsh's
        # built-in default, kept here so we own the value explicitly.
        export LSCOLORS='Gxfxcxdxbxegedabagacad'
        export LS_COLORS='di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
        ;;
    *)
        print -ru2 "theme.zsh: unknown TERMINAL_THEME '$TERMINAL_THEME'"
        ;;
esac

# BSD ls (macOS default) needs -G to actually use LSCOLORS.
case "$OSTYPE" in
    (darwin|freebsd)*) alias ls='ls -G' ;;
    *)                 alias ls='ls --color=tty' ;;
esac
