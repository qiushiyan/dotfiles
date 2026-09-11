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
#
# Everything the theme owns is applied by _theme_apply so it can run twice: once
# here at startup, and again from the _theme_sync precmd below whenever the file
# changes under a running shell (theme-set from another pane, or from the tmux
# prefix-t menu while a long-running command such as claude held this shell).
# Without the re-run, the first prompt after that command exits renders in the
# old palette until `exec zsh`.

export DISABLE_LS_COLORS=true

_theme_apply() {
    local _t
    # builtin read, not $(tr ...): this also runs per prompt, so no fork.
    if [[ -r "$HOME/.config/terminal-theme" ]] && read -r _t < "$HOME/.config/terminal-theme"; then
        TERMINAL_THEME=${_t//[[:space:]]/}
    fi
    : "${TERMINAL_THEME:=gruber_darker}"
    export TERMINAL_THEME

case "$TERMINAL_THEME" in
    gruber_darker)
        # Gruber charcoal: bold cyan directories; readable source gray suggestions.
        export LSCOLORS='Gxfxcxdxbxegedabagacad'
        export LS_COLORS='di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
        # #808080 replaces Zed's near-black ANSI slot 8, for 4.50:1 contrast.
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
        export DELTA_FEATURES='+dark-mode'
        export DFT_BACKGROUND='dark'
        ;;
    catppuccin_mocha)
        # Dark bg: bold/bright dir for emphasis. Matches oh-my-zsh's
        # built-in default, kept here so we own the value explicitly.
        export LSCOLORS='Gxfxcxdxbxegedabagacad'
        export LS_COLORS='di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
        # On the dark bg the plugin's default fg=8 already reads well; set it
        # explicitly so the value is owned here alongside the light variant.
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
        # delta (git pager) + difftastic follow the same light/dark choice.
        export DELTA_FEATURES='+dark-mode'
        export DFT_BACKGROUND='dark'
        ;;
    tailwind_light)
        # White bg (#ffffff), like the other light themes: non-bold dark hues. The
        # LSCOLORS/LS_COLORS codes index the terminal's 16-color palette, which
        # ghostty's tailwind-light-contrast theme supplies, so the light-theme
        # strings carry over unchanged.
        export LSCOLORS='exfxcxdxbxegedabagacad'
        export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
        # Mid-gray (242 = #6c6c6c, not remapped by the theme) for the grayed
        # inline suggestion — reads clearly on the white paper bg.
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=242'
        # delta (git pager) + difftastic follow the same light/dark choice.
        export DELTA_FEATURES='+light-mode'
        export DFT_BACKGROUND='light'
        ;;
    tokyo_night_moon)
        # Dark bg (#222436): bold/bright dir for emphasis, same as catppuccin_mocha.
        export LSCOLORS='Gxfxcxdxbxegedabagacad'
        export LS_COLORS='di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
        # On the dark bg the plugin's default fg=8 reads well; set it explicitly
        # so the value is owned here alongside the other arms.
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
        # delta (git pager) + difftastic follow the same light/dark choice.
        export DELTA_FEATURES='+dark-mode'
        export DFT_BACKGROUND='dark'
        ;;
    gruvbox_dark)
        # Dark bg (#282828): bold/bright dir for emphasis, same as the other dark arms.
        export LSCOLORS='Gxfxcxdxbxegedabagacad'
        export LS_COLORS='di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
        # Dark bg → the plugin default fg=8 reads well; set explicitly to own it.
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
        # delta (git pager) + difftastic follow the same light/dark choice.
        export DELTA_FEATURES='+dark-mode'
        export DFT_BACKGROUND='dark'
        ;;
    vitesse_light_soft)
        # Soft cream bg (#f1f0e9), like the other light themes: non-bold dark hues. The
        # codes index the 16-color palette ghostty's vitesse-light-soft theme
        # supplies, so the light-theme strings carry over unchanged.
        export LSCOLORS='exfxcxdxbxegedabagacad'
        export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
        # fg=8 maps to vitesse's #aaaaaa — too faint on the cream bg; the fixed
        # mid-gray (242 = #6c6c6c) reads clearly while staying muted.
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=242'
        # delta (git pager) + difftastic follow the same light/dark choice.
        export DELTA_FEATURES='+light-mode'
        export DFT_BACKGROUND='light'
        ;;
    night_owl)
        # Deep navy bg (#011627): bold/bright dir for emphasis, same as the other dark arms.
        export LSCOLORS='Gxfxcxdxbxegedabagacad'
        export LS_COLORS='di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
        # fg=8 maps to Night Owl's #575656 — dim but legible on the navy bg; own it explicitly.
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
        # delta (git pager) + difftastic follow the same light/dark choice.
        export DELTA_FEATURES='+dark-mode'
        export DFT_BACKGROUND='dark'
        ;;
    orng_light)
        # Peach paper bg (#fff7f1), like the other light themes: non-bold dark hues. The
        # codes index the 16-color palette ghostty's orng-light theme supplies
        # (dir = its string blue #0062d1), so the light-theme strings carry over.
        export LSCOLORS='exfxcxdxbxegedabagacad'
        export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
        # fg=8 maps to orng's #8a8a8a — borderline on the peach bg; the fixed
        # mid-gray (242 = #6c6c6c) reads clearly while staying muted.
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=242'
        # delta (git pager) + difftastic follow the same light/dark choice.
        export DELTA_FEATURES='+light-mode'
        export DFT_BACKGROUND='light'
        ;;
    forest_night)
        # Blue-slate bg (#1a2125): bold/bright dir for emphasis, same as the other dark arms.
        export LSCOLORS='Gxfxcxdxbxegedabagacad'
        export LS_COLORS='di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
        # fg=8 maps to the ghostty palette's #6b7280 (the theme's dark_foreground,
        # chosen over the VS Code #4a5568 bright-black for exactly this) — legible on the slate.
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
        # delta (git pager) + difftastic follow the same light/dark choice.
        export DELTA_FEATURES='+dark-mode'
        export DFT_BACKGROUND='dark'
        ;;
    waffle_cat)
        # Syrup bg; ANSI blue is honey, so bold directories stay warm.
        export LSCOLORS='Exfxcxdxbxegedabagacad'
        export LS_COLORS='di=1;34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
        # Upstream oat #a58c82 is 5.03:1 on #292025; no bright-black substitution.
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
        export DELTA_FEATURES='+dark-mode'
        export DFT_BACKGROUND='dark'
        ;;
    vellum)
        # White paper bg (#ffffff), like the other light themes: non-bold dark hues.
        # The codes index the 16-color palette ghostty's vellum theme supplies
        # (dir = Tailwind blue-700 #1447e6), so the light-theme strings carry over.
        export LSCOLORS='exfxcxdxbxegedabagacad'
        export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
        # fg=8 is vellum's neutral-500 #737373 (4.7:1 on white); the fixed mid-gray
        # 242 = #6c6c6c matches the other light arms and stays muted.
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=242'
        # delta (git pager) + difftastic follow the same light/dark choice.
        export DELTA_FEATURES='+light-mode'
        export DFT_BACKGROUND='light'
        ;;
    token_meridian_light)
        # Meridian paper: non-bold ANSI blue directories, upstream comment ink suggestions.
        export LSCOLORS='exfxcxdxbxegedabagacad'
        export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
        export DELTA_FEATURES='+light-mode'
        export DFT_BACKGROUND='light'
        ;;
    token_ultra_dark)
        # Ultra charcoal: bright cyan directories; upstream fg3 suggestions (4.3:1).
        export LSCOLORS='Gxfxcxdxbxegedabagacad'
        export LS_COLORS='di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
        export DELTA_FEATURES='+dark-mode'
        export DFT_BACKGROUND='dark'
        ;;
    raindrop)
        # Blue frame (#152435); original comment slate in ANSI 8 is 3.82:1.
        export LSCOLORS='Gxfxcxdxbxegedabagacad'
        export LS_COLORS='di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
        export DELTA_FEATURES='+dark-mode'
        export DFT_BACKGROUND='dark'
        ;;
    *)
        print -ru2 "theme.zsh: unknown TERMINAL_THEME '$TERMINAL_THEME'"
        ;;
esac
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
