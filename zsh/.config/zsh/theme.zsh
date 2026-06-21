# Terminal theme switcher — owns ls/completion colors and the zsh-autosuggestions
# inline color, keyed off $TERMINAL_THEME. Sourced from .zshenv (before .zshrc /
# oh-my-zsh). See docs/theming.md for the cross-tool system and how to switch.
#
# Local mechanics: DISABLE_LS_COLORS=true makes oh-my-zsh leave LSCOLORS/LS_COLORS
# to us (so we own the `ls` alias here too). The codes index the terminal's
# 16-color palette (set by Ghostty's theme); the per-theme arms differ only to
# tune bold-vs-plain for the background.

# The state file is the single source of truth — read it unconditionally so an
# inherited value can never win. This matters inside tmux: the server captures
# TERMINAL_THEME into its environment the first time it launches and hands that
# (now stale) value to every new pane, so guarding the read on `-z` would pin
# panes to whatever theme was active when the server started — the prompt then
# renders the old palette inside tmux while new shells outside tmux track the
# file. Fall back to an inherited value, then the default, only when the file is
# unreadable.
if [[ -r "$HOME/.config/terminal-theme" ]]; then
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
        # zsh-autosuggestions' grayed inline suggestion. The plugin's default
        # fg=8 maps to flexoki's #b7b5ac here — near-invisible on the #fffcf0
        # paper bg (worsened by background-opacity). A darker fixed grayscale
        # (242 = #6c6c6c, not remapped by the theme) reads clearly while
        # staying muted. .zshrc loads the plugin after this, and it only
        # applies its fg=8 default when this is unset.
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=242'
        ;;
    catppuccin_mocha)
        # Dark bg: bold/bright dir for emphasis. Matches oh-my-zsh's
        # built-in default, kept here so we own the value explicitly.
        export LSCOLORS='Gxfxcxdxbxegedabagacad'
        export LS_COLORS='di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
        # On the dark bg the plugin's default fg=8 already reads well; set it
        # explicitly so the value is owned here alongside the light variant.
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
        ;;
    tailwind_light)
        # White bg (#ffffff), like flexoki_light: non-bold dark hues. The
        # LSCOLORS/LS_COLORS codes index the terminal's 16-color palette, which
        # ghostty's tailwind-light-contrast theme supplies, so the flexoki_light
        # strings carry over unchanged.
        export LSCOLORS='exfxcxdxbxegedabagacad'
        export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
        # Mid-gray (242 = #6c6c6c, not remapped by the theme) for the grayed
        # inline suggestion — reads clearly on the white paper bg.
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=242'
        ;;
    tokyo_night_moon)
        # Dark bg (#222436): bold/bright dir for emphasis, same as catppuccin_mocha.
        export LSCOLORS='Gxfxcxdxbxegedabagacad'
        export LS_COLORS='di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
        # On the dark bg the plugin's default fg=8 reads well; set it explicitly
        # so the value is owned here alongside the other arms.
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
        ;;
    gruvbox_dark)
        # Dark bg (#282828): bold/bright dir for emphasis, same as the other dark arms.
        export LSCOLORS='Gxfxcxdxbxegedabagacad'
        export LS_COLORS='di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
        # Dark bg → the plugin default fg=8 reads well; set explicitly to own it.
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
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
