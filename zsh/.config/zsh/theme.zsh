# Terminal theme switcher — owns ls/completion colors and the zsh-autosuggestions
# inline color, keyed off $TERMINAL_THEME. Sourced from .zshenv (before .zshrc /
# oh-my-zsh). See docs/theming.md for the cross-tool system and how to switch.
#
# Local mechanics: DISABLE_LS_COLORS=true makes oh-my-zsh leave LSCOLORS/LS_COLORS
# to us (so we own the `ls` alias here too). The codes index the terminal's
# 16-color palette (set by Ghostty's theme), so one row per theme is enough.

# The state file is the single source of truth — read it unconditionally so an
# inherited value can never win. This matters inside tmux: the server captures
# TERMINAL_THEME into its environment the first time it launches and hands that
# (now stale) value to every new pane, so guarding the read on `-z` would pin
# panes to whatever theme was active when the server started — the prompt then
# renders the old palette inside tmux while new shells outside tmux track the
# file. Fall back to an inherited value, then the default, only when the file is
# unreadable.
#
# Everything the theme owns is applied by _theme_apply so it can run twice: once
# here at startup, and again from the _theme_sync precmd below whenever the file
# changes under a running shell (theme-set from another pane, or from the tmux
# prefix-t menu while a long-running command such as claude held this shell).
# Without the re-run, the first prompt after that command exits renders in the
# old palette until `exec zsh`.

export DISABLE_LS_COLORS=true

# Theme name → "<bg> <suggestion fg> [<dir LSCOLORS letter> <dir LS_COLORS>]".
# bg (dark|light) sets the rest: directories bold bright cyan on dark (G,
# 1;36) and plain blue on light (e, 34), and delta's and difftastic's mode. A
# row overrides the directory pair only when its palette needs it. The
# suggestion fg is zsh-autosuggestions' color: ANSI 8 (the theme's bright
# black) where it reads on the background, else the fixed mid-gray 242
# (#6c6c6c), which no theme remaps. Every theme-set name needs a row.
typeset -gA _THEME_SPEC=(
    gruber_darker        'dark 8'         # charcoal; #808080 replaces Zed's near-black slot 8 (4.50:1)
    catppuccin_mocha     'dark 8'         # oh-my-zsh's own defaults, owned here explicitly
    tailwind_light       'light 242'      # white #ffffff
    tokyo_night_moon     'dark 8'         # #222436
    gruvbox_dark         'dark 8'         # #282828
    vitesse_light_soft   'light 242'      # cream #f1f0e9; its slot 8 #aaaaaa is too faint
    night_owl            'dark 8'         # navy #011627; slot 8 #575656, dim but legible
    orng_light           'light 242'      # peach #fff7f1, dir = string blue #0062d1; slot 8 #8a8a8a borderline
    forest_night         'dark 8'         # slate #1a2125; slot 8 is the palette's #6b7280, chosen for this
    waffle_cat           'dark 8 E 1;34'  # syrup; ANSI blue is honey, so bold dirs stay warm; oat slot 8 5.03:1
    vellum               'light 242'      # white, dir = blue-700 #1447e6; slot 8 #737373 (4.7:1), 242 matches
    token_meridian_light 'light 8'        # Meridian paper; slot 8 is the upstream comment ink
    token_ultra_dark     'dark 8'         # ultra charcoal; slot 8 is upstream fg3 (4.3:1)
    raindrop             'dark 8'         # blue frame #152435; slot 8 is the comment slate (3.82:1)
)

_theme_apply() {
    emulate -L zsh
    local _t _bg _bsd _gnu
    local -a _spec
    # builtin read, not $(tr ...): this also runs per prompt, so no fork.
    if [[ -r "$HOME/.config/terminal-theme" ]] && read -r _t < "$HOME/.config/terminal-theme"; then
        TERMINAL_THEME=${_t//[[:space:]]/}
    fi
    : "${TERMINAL_THEME:=gruber_darker}"
    export TERMINAL_THEME

    _spec=(${=_THEME_SPEC[$TERMINAL_THEME]-})
    if (( ! $#_spec )); then
        print -ru2 "theme.zsh: unknown TERMINAL_THEME '$TERMINAL_THEME'"
        return
    fi
    _bg=$_spec[1] _bsd=G _gnu='1;36'
    [[ $_bg == light ]] && _bsd=e _gnu=34
    (( $#_spec > 2 )) && _bsd=$_spec[3] _gnu=$_spec[4]
    export LSCOLORS="${_bsd}xfxcxdxbxegedabagacad"
    export LS_COLORS="di=${_gnu}:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43"
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=$_spec[2]"
    export DELTA_FEATURES="+$_bg-mode" DFT_BACKGROUND=$_bg
}

_theme_apply

# Keep a running interactive shell in step with the file. Runs before every
# prompt; the common path is one builtin read + a string compare (no fork), and
# the full re-apply only happens when the name actually changed. Registered
# here, from .zshenv, so it lands in precmd_functions ahead of oh-my-posh's
# _omp_precmd (registered at the end of .zshrc) — hooks run in registration
# order, and omp spawns its renderer with the shell's *current* env, so the
# updated TERMINAL_THEME reaches the very next prompt, not the one after.
if [[ -o interactive ]]; then
    _theme_sync() {
        local _t
        [[ -r "$HOME/.config/terminal-theme" ]] && read -r _t < "$HOME/.config/terminal-theme" || return 0
        _t=${_t//[[:space:]]/}
        [[ -n $_t && $_t != "$TERMINAL_THEME" ]] && _theme_apply
        return 0
    }
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _theme_sync
fi

# BSD ls (macOS default) needs -G to actually use LSCOLORS.
case "$OSTYPE" in
    (darwin|freebsd)*) alias ls='ls -G' ;;
    *)                 alias ls='ls --color=tty' ;;
esac
