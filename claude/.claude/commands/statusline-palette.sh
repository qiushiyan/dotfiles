# shellcheck shell=bash disable=SC2034  # every slot is read by the renderer
# statusline-palette.sh — the Claude statusline's colours, one `case` arm per
# theme: six truecolor slots (CYAN/GREEN/YELLOW/RED/PINK/LAVENDER) chosen for
# contrast against that theme's background, so the render code stays
# theme-agnostic. Data only, sourced by statusline-command.sh with $THEME set;
# a theme port patches this file and never the renderer. Returns 1 for a theme
# with no arm. See docs/theming.md for the cross-tool system and how to add a
# theme.

# 24-bit truecolor escape: $'\033[38;2;R;G;Bm'
case "$THEME" in
    catppuccin_mocha)
        CYAN=$'\033[38;2;137;180;250m'      # Blue #89B4FA
        GREEN=$'\033[38;2;166;227;161m'     # Green #A6E3A1
        YELLOW=$'\033[38;2;250;179;135m'    # Peach #FAB387
        RED=$'\033[38;2;243;139;168m'       # Red #F38BA8
        PINK=$'\033[38;2;245;194;231m'      # Pink #F5C2E7
        LAVENDER=$'\033[38;2;180;190;254m'  # Lavender #B4BEFE
        ;;
    gruber_darker)
        # Zed Gruber Darker accents on #181818.
        CYAN=$'\033[38;2;78;201;176m'  # #4ec9b0
        GREEN=$'\033[38;2;115;201;54m'  # #73c936
        YELLOW=$'\033[38;2;255;221;51m'  # #ffdd33
        RED=$'\033[38;2;244;56;65m'  # #f43841
        PINK=$'\033[38;2;158;149;199m'  # #9e95c7
        LAVENDER=$'\033[38;2;150;166;200m'  # #96a6c8
        ;;
    tailwind_light)
        # Light white bg (#ffffff) — Tailwind's darker (non-bright) accents for contrast
        CYAN=$'\033[38;2;0;146;184m'        # Cyan #0092b8
        GREEN=$'\033[38;2;0;153;102m'       # Green #009966
        YELLOW=$'\033[38;2;225;113;0m'      # Amber #e17100
        RED=$'\033[38;2;199;0;54m'          # Red #c70036
        PINK=$'\033[38;2;152;16;250m'       # Purple #9810fa
        LAVENDER=$'\033[38;2;20;71;230m'    # Blue #1447e6
        ;;
    tokyo_night_moon)
        # Dark bg (#222436) — Tokyo Night Moon's bright accents read well on it
        CYAN=$'\033[38;2;134;225;252m'      # Cyan #86e1fc
        GREEN=$'\033[38;2;195;232;141m'     # Green #c3e88d
        YELLOW=$'\033[38;2;255;199;119m'    # Yellow #ffc777
        RED=$'\033[38;2;255;117;127m'       # Red #ff757f
        PINK=$'\033[38;2;192;153;255m'      # Magenta #c099ff
        LAVENDER=$'\033[38;2;130;170;255m'  # Blue #82aaff
        ;;
    gruvbox_dark)
        # Dark bg (#282828) — gruvbox's bright accents read well on it
        CYAN=$'\033[38;2;142;192;124m'      # Aqua #8ec07c
        GREEN=$'\033[38;2;184;187;38m'      # Green #b8bb26
        YELLOW=$'\033[38;2;250;189;47m'     # Yellow #fabd2f
        RED=$'\033[38;2;251;73;52m'         # Red #fb4934
        PINK=$'\033[38;2;211;134;155m'      # Purple #d3869b
        LAVENDER=$'\033[38;2;131;165;152m'  # Blue #83a598
        ;;
    night_owl)
        # Deep navy bg (#011627) — Night Owl's pastel accents read well on it.
        # GREEN is the signature lime (#addb67, its ANSI-yellow slot), not the
        # neon terminal green #22da6e, which glares against the navy.
        CYAN=$'\033[38;2;127;219;202m'      # Bright cyan #7fdbca
        GREEN=$'\033[38;2;173;219;103m'     # Lime #addb67
        YELLOW=$'\033[38;2;255;235;149m'    # Bright yellow #ffeb95
        RED=$'\033[38;2;239;83;80m'         # Red #ef5350
        PINK=$'\033[38;2;199;146;234m'      # Magenta #c792ea
        LAVENDER=$'\033[38;2;130;170;255m'  # Blue #82aaff
        ;;
    vitesse_light_soft)
        # Soft cream bg (#f1f0e9) — Vitesse's muted dark accents for contrast.
        # YELLOW is the darker Vitesse gold (#998418, its property color), not
        # the terminal yellow #bda437, which washes out on the cream bg.
        CYAN=$'\033[38;2;41;147;163m'       # Cyan #2993a3
        GREEN=$'\033[38;2;30;117;79m'       # Green #1e754f
        YELLOW=$'\033[38;2;153;132;24m'     # Gold #998418
        RED=$'\033[38;2;171;89;89m'         # Red #ab5959
        PINK=$'\033[38;2;161;56;101m'       # Magenta #a13865
        LAVENDER=$'\033[38;2;41;106;163m'   # Blue #296aa3
        ;;
    orng_light)
        # Peach paper bg (#fff7f1) — orng's saturated accents, one step deeper
        # where the terminal value washes out. GREEN is the dim green (#317b46),
        # not the terminal green #3d9a57, which goes pale on the warm bg.
        CYAN=$'\033[38;2;49;135;149m'       # Cyan #318795
        GREEN=$'\033[38;2;49;123;70m'       # Dim green #317b46
        YELLOW=$'\033[38;2;176;133;31m'     # Gold #b0851f
        RED=$'\033[38;2;209;56;61m'         # Red #d1383d
        PINK=$'\033[38;2;236;91;43m'        # Orange accent #EC5B2B
        LAVENDER=$'\033[38;2;0;98;209m'     # String blue #0062d1
        ;;
    forest_night)
        # Blue-slate bg (#1a2125) — Forest Night's accents read well on it.
        # RED is the theme's rosy error/deleted color (#c78a7a, its bright-red
        # slot, 5.7:1), not the hot-pink terminal red #E91E63, which sits at
        # 3.7:1 and reads as magenta beside PINK.
        CYAN=$'\033[38;2;78;205;196m'       # Teal #4ECDC4
        GREEN=$'\033[38;2;143;188;143m'     # Sage accent #8FBC8F
        YELLOW=$'\033[38;2;243;156;18m'     # Amber #F39C12
        RED=$'\033[38;2;199;138;122m'       # Rose #c78a7a
        PINK=$'\033[38;2;155;89;182m'       # Purple #9B59B6
        LAVENDER=$'\033[38;2;102;217;239m'  # Sky blue #66D9EF
        ;;
    waffle_cat)
        # Upstream accents on syrup #292025; the weakest is rust at 4.70:1.
        CYAN=$'\033[38;2;158;184;178m'  # cyan #9eb8b2
        GREEN=$'\033[38;2;159;173;104m'  # green #9fad68
        YELLOW=$'\033[38;2;228;197;109m'  # bright_yellow #e4c56d
        RED=$'\033[38;2;207;115;88m'  # red #cf7358
        PINK=$'\033[38;2;201;140;151m'  # magenta #c98c97
        LAVENDER=$'\033[38;2;200;125;42m'  # accent #c87d2a
        ;;
    vellum)
        # White paper bg (#ffffff). PINK (branch) is the text-safe ochre accent
        # #9a6a18, not the sampled amber #cb953d (2.7:1 on white); YELLOW
        # (context warning) is Tailwind amber-700 so warnings read as orange.
        CYAN=$'\033[38;2;0;117;149m'        # Cyan-800 #007595
        GREEN=$'\033[38;2;0;130;54m'        # Green-700 #008236
        YELLOW=$'\033[38;2;187;77;0m'       # Amber-700 #bb4d00
        RED=$'\033[38;2;193;0;7m'           # Red-700 #c10007
        PINK=$'\033[38;2;154;106;24m'       # Ochre accent #9a6a18
        LAVENDER=$'\033[38;2;20;71;230m'    # Blue-700 #1447e6
        ;;
    token_meridian_light)
        # Upstream semantic diagnostic blue, ochre warning, plum and violet accents.
        CYAN=$'\033[38;2;9;91;98m' # #095b62
        GREEN=$'\033[38;2;0;95;47m' # #005f2f
        YELLOW=$'\033[38;2;132;57;0m' # #843900
        RED=$'\033[38;2;40;111;192m' # #286fc0
        PINK=$'\033[38;2;122;31;122m' # #7a1f7a
        LAVENDER=$'\033[38;2;75;31;163m' # #4b1fa3
        ;;
    token_ultra_dark)
        # Ultra: quiet fg1 directory, signature peach branch; sage/gold/rose
        # retain semantic status contrast on charcoal. All colors are upstream.
        CYAN=$'\033[38;2;126;188;187m' # #7ebcbb
        GREEN=$'\033[38;2;154;181;142m' # #9ab58e
        YELLOW=$'\033[38;2;247;201;136m' # #f7c988
        RED=$'\033[38;2;221;131;132m' # #dd8384
        PINK=$'\033[38;2;237;149;116m' # Branch: accent #ed9574
        LAVENDER=$'\033[38;2;167;162;153m' # Directory: fg1 #a7a299
        ;;
    raindrop)
        # Original cool tokens: ice warning and deletion-violet error; no warm hues.
        CYAN=$'\033[38;2;46;217;255m' # #2ED9FF
        GREEN=$'\033[38;2;26;214;181m' # #1AD6B5
        YELLOW=$'\033[38;2;157;216;235m' # #9DD8EB
        RED=$'\033[38;2;153;132;238m' # #9984EE
        PINK=$'\033[38;2;153;132;238m' # #9984EE
        LAVENDER=$'\033[38;2;157;216;235m' # #9DD8EB
        ;;
    *)
        return 1
        ;;
esac
