# ~/.config/zsh/utils.zsh
# Miscellaneous utility functions

# --------------------------------------------------------------------
# Reset Kitty Keyboard Protocol (KKP) state before each prompt.
# Workaround for Claude Code sometimes leaving KKP enabled on exit,
# which causes Ctrl+C/Ctrl+D to send CSI u sequences (^[[99;5u)
# instead of raw control characters. See anthropics/claude-code#38761.
# Safe to remove once Claude Code fixes this upstream.
# --------------------------------------------------------------------
_reset_kkp_precmd() {
  # Write directly to /dev/tty to bypass any stdout redirection from plugins
  printf '\e[<u\e[>0m' > /dev/tty 2>/dev/null
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _reset_kkp_precmd

# --------------------------------------------------------------------
# ccclean - Clean old Claude Code sessions
# --------------------------------------------------------------------
ccclean() {
  local days=7
  local min_messages=0
  local force=false
  local project_filter=""
  local list_projects=false
  local claude_dir="$HOME/.claude/projects"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--force) force=true; shift ;;
      -d|--days) days="$2"; shift 2 ;;
      -m|--min-messages) min_messages="$2"; shift 2 ;;
      -p|--project) project_filter="$2"; shift 2 ;;
      -l|--list) list_projects=true; shift ;;
      -h|--help) _ccclean_help; return 0 ;;
      -*) echo "ccclean: unknown option '$1'" >&2; _ccclean_help; return 1 ;;
      *) days="$1"; shift ;;
    esac
  done

  if [[ ! -d "$claude_dir" ]]; then
    echo "ccclean: Claude projects directory not found: $claude_dir" >&2
    return 1
  fi

  # List projects mode
  if $list_projects; then
    echo "Available projects:"
    local pname session_count psize
    for project_dir in "$claude_dir"/*; do
      [[ ! -d "$project_dir" ]] && continue
      pname="${project_dir:t}"
      session_count=$(find "$project_dir" -maxdepth 1 -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
      psize=$(du -sh "$project_dir" 2>/dev/null | cut -f1)
      echo "  $pname ($session_count sessions, $psize)"
    done
    return 0
  fi

  if ! command -v jq &>/dev/null; then
    echo "ccclean: jq is required but not installed" >&2
    return 1
  fi

  local cutoff_date cutoff_display
  cutoff_date=$(date -v-${days}d +%s 2>/dev/null || date -d "$days days ago" +%s)
  cutoff_display=$(date -r "$cutoff_date" +%Y-%m-%d 2>/dev/null || date -d "@$cutoff_date" +%Y-%m-%d)

  echo "Claude Code session cleanup"
  echo "Days threshold: $days (before $cutoff_display)"
  [[ "$min_messages" -gt 0 ]] && echo "Min messages: $min_messages"
  [[ -n "$project_filter" ]] && echo "Project filter: *$project_filter*"
  $force && echo "Mode: DELETE" || echo "Mode: DRY RUN (use -f to delete)"
  echo "----------------------------------------"

  local deleted=0
  local skipped_safelist=0
  local total_size=0
  local project_name file_mtime session_id session_dir file_size file_size_human file_date dir_size index_file tmp_index total_size_human
  local safelist_ids msg_count skip_reason extracted_id cc_fork_dir="$HOME/.cc-fork"

  # Build global safelist from ~/.cc-fork/*/base.json
  safelist_ids=()
  if [[ -d "$cc_fork_dir" ]]; then
    for base_json in "$cc_fork_dir"/*/base.json; do
      [[ ! -f "$base_json" ]] && continue
      extracted_id=$(jq -r '.id // empty' "$base_json" 2>/dev/null)
      [[ -n "$extracted_id" ]] && safelist_ids+=("$extracted_id")
    done
  fi

  for project_dir in "$claude_dir"/*; do
    [[ ! -d "$project_dir" ]] && continue
    project_name="${project_dir:t}"

    # Apply project filter (substring match)
    if [[ -n "$project_filter" && "$project_name" != *"$project_filter"* ]]; then
      continue
    fi

    for session_file in "$project_dir"/*.jsonl(N); do
      [[ ! -f "$session_file" ]] && continue
      [[ "${session_file:t}" == "sessions-index.json" ]] && continue

      session_id="${${session_file:t}%.jsonl}"

      # Check safelist
      if [[ " ${safelist_ids[*]} " == *" $session_id "* ]]; then
        ((skipped_safelist++))
        continue
      fi

      file_mtime=$(stat -f %m "$session_file" 2>/dev/null || stat -c %Y "$session_file")

      # Check if session should be deleted (old OR low message count)
      skip_reason=""
      msg_count=$(grep -c '"type":"user"\|"type":"assistant"' "$session_file" 2>/dev/null)
      [[ -z "$msg_count" ]] && msg_count=0

      if [[ "$file_mtime" -lt "$cutoff_date" ]]; then
        skip_reason="old"
      elif [[ "$msg_count" -lt "$min_messages" ]]; then
        skip_reason="low-msg"
      fi

      if [[ -n "$skip_reason" ]]; then
        session_dir="$project_dir/$session_id"
        file_size=$(stat -f %z "$session_file" 2>/dev/null || stat -c %s "$session_file")
        file_size_human=$(numfmt --to=iec "$file_size" 2>/dev/null || echo "${file_size}B")
        file_date=$(date -r "$file_mtime" +%Y-%m-%d 2>/dev/null || date -d "@$file_mtime" +%Y-%m-%d)

        if $force; then
          echo "Deleting: $project_name/${session_id:0:8}... ($file_size_human, $file_date, ${msg_count}msg, $skip_reason)"
          rm -f "$session_file"
          if [[ -d "$session_dir" ]]; then
            dir_size=$(du -sk "$session_dir" 2>/dev/null | cut -f1)
            rm -rf "$session_dir"
            total_size=$((total_size + dir_size * 1024))
          fi
          total_size=$((total_size + file_size))

          # Update sessions-index.json
          index_file="$project_dir/sessions-index.json"
          if [[ -f "$index_file" ]]; then
            tmp_index=$(mktemp)
            jq --arg sid "$session_id" '.entries = [.entries[] | select(.sessionId != $sid)]' "$index_file" > "$tmp_index" 2>/dev/null
            if [[ $? -eq 0 ]]; then
              mv "$tmp_index" "$index_file"
            else
              rm -f "$tmp_index"
            fi
          fi
        else
          echo "[dry run] $project_name/${session_id:0:8}... ($file_size_human, $file_date, ${msg_count}msg, $skip_reason)"
          total_size=$((total_size + file_size))
          if [[ -d "$session_dir" ]]; then
            dir_size=$(du -sk "$session_dir" 2>/dev/null | cut -f1)
            total_size=$((total_size + dir_size * 1024))
          fi
        fi
        ((deleted++))
      fi
    done
  done

  total_size_human=$(numfmt --to=iec "$total_size" 2>/dev/null || echo "${total_size}B")
  echo "----------------------------------------"
  if $force; then
    echo "Deleted: $deleted session(s), $total_size_human freed"
  else
    echo "Found: $deleted session(s), $total_size_human would be freed"
  fi
  [[ $skipped_safelist -gt 0 ]] && echo "Skipped: $skipped_safelist safelisted session(s)"
}

_ccclean_help() {
  cat <<'EOF'
Usage: ccclean [options] [days]

Clean old Claude Code sessions from ~/.claude/projects.
Default mode is dry-run (preview only).

Deletion criteria (OR logic):
  - Sessions older than N days (default: 7)
  - Sessions with fewer than M messages (disabled by default)

Safelist:
  Sessions listed in ~/.cc-fork/*/base.json (via 'id' field)
  are automatically protected from deletion.

Options:
  -d, --days <n>          Days threshold (default: 7)
  -m, --min-messages <n>  Also delete sessions with <N messages (default: 0, disabled)
  -p, --project <s>       Filter by project name (substring match)
  -l, --list              List all projects with session counts
  -f, --force             Actually delete (default is dry-run preview)
  -h, --help              Show this help message

Examples:
  ccclean                     Preview sessions older than 7 days
  ccclean -l                  List all projects
  ccclean -p TabType          Preview for TabType project only
  ccclean -p TabType -f       Delete for TabType project
  ccclean -m 6                Also delete sessions with <6 messages
  ccclean -d 14 -m 10         Delete >14 days old OR <10 messages

What gets deleted:
  - Session transcript files (<uuid>.jsonl)
  - Session directories (<uuid>/) with subagents and tool-results
  - Entries removed from sessions-index.json
EOF
}

# --------------------------------------------------------------------
# x - Claude with skip permissions
# --------------------------------------------------------------------
x() {
  claude --dangerously-skip-permissions "$@"
}

# --------------------------------------------------------------------
# zed - Wrapper to prevent opening root
# --------------------------------------------------------------------
zed() {
  if [[ "$1" == "/" ]]; then
    echo "Blocked: 'zed /' — use 'command zed /' to override"
    return 1
  fi
  command zed "$@"
}

# --------------------------------------------------------------------
# rm - Safe wrapper to block recursive deletion of critical directories
# Bypass with: command rm -rf <path>
# --------------------------------------------------------------------
rm() {
  # Only intervene when -r or -R (recursive) is present
  local has_recursive=false
  local args=()
  for arg in "$@"; do
    case "$arg" in
      --)           args+=("$arg"); break ;;
      -r|-R|--recursive) has_recursive=true; args+=("$arg") ;;
      -*)
        # Check combined short flags: -rf, -Rf, etc.
        if [[ "$arg" =~ ^-[^-]*[rR] ]]; then
          has_recursive=true
        fi
        args+=("$arg")
        ;;
      *)  args+=("$arg") ;;
    esac
  done

  if $has_recursive; then
    local protected=(
      "$HOME"
      "/"
      "/System"
      "/Applications"
      "/Users"
      "/etc"
      "/var"
      "/usr"
      "/opt"
      "$HOME/Documents"
      "$HOME/Desktop"
      "$HOME/Downloads"
      "$HOME/dotfiles"
      "$HOME/workspace"
    )

    for arg in "$@"; do
      [[ "$arg" == -* ]] && continue
      # Resolve to absolute path, strip trailing slashes
      local resolved="${arg/#\~/$HOME}"
      [[ "$resolved" != /* ]] && resolved="$PWD/$resolved"
      resolved="${resolved%/}"
      # Resolve .. and symlinks
      resolved="$(cd "$resolved" 2>/dev/null && pwd -P \
        || python3 -c 'import os,sys; print(os.path.normpath(sys.argv[1]))' "$resolved" 2>/dev/null \
        || echo "$resolved")"

      for p in "${protected[@]}"; do
        if [[ "$resolved" == "${p%/}" ]]; then
          print -P "%F{red}Blocked:%f rm -r on protected path: $resolved" >&2
          echo "Use 'command rm' to override if you really mean it." >&2
          return 1
        fi
      done
    done
  fi

  command rm "$@"
}


# --------------------------------------------------------------------
# cpwd - Copy current directory path to clipboard
# --------------------------------------------------------------------
cpwd() { local p="${PWD/#$HOME/~}"; echo "$p" | pbcopy; echo "$p" }

# --------------------------------------------------------------------
# ccproxy - Toggle AI proxy settings for Claude Code / Codex etc.
# Usage: ccproxy on | off | (no args to check status)
# --------------------------------------------------------------------
ccproxy() {
  case "$1" in
    on)
      export ANTHROPIC_BASE_URL="$CCPROXY_BASE_URL"
      export ANTHROPIC_API_KEY="$CCPROXY_API_KEY"
      echo "AI proxy ON"
      ;;
    off)
      unset ANTHROPIC_BASE_URL
      unset ANTHROPIC_API_KEY
      echo "AI proxy OFF"
      ;;
    *)
      if [[ -n "$ANTHROPIC_BASE_URL" ]]; then
        echo "AI proxy is ON"
      else
        echo "AI proxy is OFF"
      fi
      ;;
  esac
}

# --------------------------------------------------------------------
# codexproxy - Toggle API proxy settings for OpenAI Codex CLI
# Uses the same proxy credentials as ccproxy (CCPROXY_BASE_URL / CCPROXY_AUTH_TOKEN)
# Usage: codexproxy on | off | (no args to check status)
# --------------------------------------------------------------------
codexproxy() {
  local config="$HOME/.codex/config.toml"
  # Resolve symlink so we edit the actual file, not replace the link
  [[ -L "$config" ]] && config="$(realpath "$config")"

  case "$1" in
    on)
      export OPENAI_API_KEY="$CCPROXY_AUTH_TOKEN"
      export OPENAI_BASE_URL="$CCPROXY_BASE_URL"

      if grep -q "codexproxy BEGIN" "$config" 2>/dev/null; then
        echo "Codex proxy ON (config already set)"
        return
      fi

      # Prepend routing keys + append provider section, wrapped in markers
      local tmp="${config}.tmp.$$"
      {
        echo '# --- codexproxy BEGIN ---'
        echo 'model_provider = "aicodewith"'
        echo 'preferred_auth_method = "apikey"'
        echo 'requires_openai_auth = true'
        echo 'enableRouteSelection = true'
        echo '# --- codexproxy END ---'
        echo ''
        cat "$config"
        echo ''
        echo '# --- codexproxy BEGIN ---'
        echo '[model_providers.aicodewith]'
        echo 'name = "aicodewith"'
        echo "base_url = \"${CCPROXY_BASE_URL}\""
        echo 'wire_api = "responses"'
        echo '# --- codexproxy END ---'
      } > "$tmp" && mv "$tmp" "$config"

      echo "Codex proxy ON"
      ;;
    off)
      unset OPENAI_API_KEY
      unset OPENAI_BASE_URL

      if [[ -f "$config" ]] && grep -q "codexproxy BEGIN" "$config"; then
        sed '/# --- codexproxy BEGIN ---/,/# --- codexproxy END ---/d' "$config" \
          > "${config}.tmp.$$" && mv "${config}.tmp.$$" "$config"
      fi

      echo "Codex proxy OFF"
      ;;
    *)
      if grep -q "codexproxy BEGIN" "$config" 2>/dev/null; then
        echo "Codex proxy is ON"
      else
        echo "Codex proxy is OFF"
      fi
      ;;
  esac
}

# --------------------------------------------------------------------
# loc - Count lines of code per file with visual bar chart
# Respects .gitignore. Uses git ls-files in repos, falls back to find.
# Usage: loc [dir] [-s size|name|ext] [-e ext1,ext2] [-n limit]
# --------------------------------------------------------------------
loc() {
  local dir="." sort_by="size" filter_ext="" limit=0 min_lines=200
  # Directories to always ignore (dot-prefixed tool/agent dirs)
  local ignore_dirs=(.claude .agents .agent .cursor .git .svn node_modules)
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -m|--min) min_lines="$2"; shift 2 ;;
      -s|--sort) sort_by="$2"; shift 2 ;;
      -e|--ext) filter_ext="$2"; shift 2 ;;
      -n|--limit) limit="$2"; shift 2 ;;
      -h|--help) _loc_help; return 0 ;;
      -*) echo "loc: unknown option '$1'" >&2; _loc_help; return 1 ;;
      *) dir="$1"; shift ;;
    esac
  done

  [[ ! -d "$dir" ]] && { echo "loc: not a directory: $dir" >&2; return 1; }

  # Collect files recursively (respect .gitignore if in a git repo)
  local files=() first_segment
  if git -C "$dir" rev-parse --is-inside-work-tree &>/dev/null; then
    while IFS= read -r f; do
      [[ -n "$f" ]] || continue
      # Skip ignored directories
      first_segment="${f%%/*}"
      if [[ "$f" == */* && ${ignore_dirs[(Ie)$first_segment]} -gt 0 ]]; then
        continue
      fi
      files+=("$f")
    done < <(git -C "$dir" ls-files --cached --others --exclude-standard 2>/dev/null)
  else
    while IFS= read -r f; do
      [[ -n "$f" ]] && files+=("${f#./}")
    done < <(find "$dir" -type f ! -name '.*' 2>/dev/null)
  fi

  [[ ${#files[@]} -eq 0 ]] && { echo "No files found."; return 0; }

  # Filter by extension
  if [[ -n "$filter_ext" ]]; then
    local filtered=() ext
    IFS=',' read -rA exts <<< "$filter_ext"
    for f in "${files[@]}"; do
      ext="${f##*.}"
      for e in "${exts[@]}"; do
        [[ "$ext" == "$e" ]] && { filtered+=("$f"); break; }
      done
    done
    files=("${filtered[@]}")
    [[ ${#files[@]} -eq 0 ]] && { echo "No files matching .$filter_ext"; return 0; }
  fi

  # Count lines per file
  local -A line_counts
  local max_lines=0 total_lines=0 count max_name_len=0 name_len
  for f in "${files[@]}"; do
    local fp="$dir/$f"
    [[ -f "$fp" ]] || continue
    # Skip binary files
    if file -b --mime-encoding "$fp" 2>/dev/null | grep -q binary; then
      continue
    fi
    count=$(wc -l < "$fp" 2>/dev/null | tr -d ' ')
    [[ -z "$count" ]] && count=0
    (( count < min_lines )) && continue
    line_counts[$f]=$count
    (( count > max_lines )) && max_lines=$count
    (( total_lines += count ))
    name_len=${#f}
    (( name_len > max_name_len )) && max_name_len=$name_len
  done

  [[ ${#line_counts} -eq 0 ]] && { echo "No files with >= $min_lines lines found."; return 0; }

  # Sort (zsh assoc arrays need manual key-by-value sorting)
  local sorted_keys=()
  case "$sort_by" in
    name) sorted_keys=(${(ok)line_counts}) ;;
    ext)  while IFS=$'\t' read -r _ k; do sorted_keys+=("$k"); done \
            < <(for k in "${(@k)line_counts}"; do printf '%s\t%s\n' "${k##*.}" "$k"; done | sort -k1,1 -k2,2) ;;
    *)    while IFS=$'\t' read -r _ k; do sorted_keys+=("$k"); done \
            < <(for k in "${(@k)line_counts}"; do printf '%d\t%s\n' "${line_counts[$k]}" "$k"; done | sort -rn) ;;
  esac

  # Apply limit
  if (( limit > 0 && limit < ${#sorted_keys[@]} )); then
    sorted_keys=("${sorted_keys[@]:0:$limit}")
  fi

  # Display
  local bar_max=30 bar_len bar ext color reset=$'\e[0m' dim=$'\e[2m'
  (( max_name_len < 4 )) && max_name_len=4
  (( max_name_len > 40 )) && max_name_len=40

  printf "\n  %${max_name_len}s  %6s  %s\n" "File" "Lines" ""
  printf "  %${max_name_len}s  %6s  %s\n" "$(printf '%0.s─' {1..$max_name_len})" "──────" "$(printf '%0.s─' {1..$bar_max})"

  for f in "${sorted_keys[@]}"; do
    count=${line_counts[$f]}
    ext="${f##*.}"

    # Color by extension
    case "$ext" in
      sh|zsh|bash)      color=$'\e[32m' ;;   # green
      py)               color=$'\e[33m' ;;   # yellow
      js|ts|jsx|tsx)    color=$'\e[36m' ;;   # cyan
      swift)            color=$'\e[38;5;208m' ;; # orange
      rs|go|c|cpp|h)    color=$'\e[31m' ;;   # red
      rb)               color=$'\e[35m' ;;   # magenta
      md|txt|rst)       color=$'\e[37m' ;;   # white
      json|yaml|yml|toml) color=$'\e[34m' ;; # blue
      *)                color=$'\e[37m' ;;   # white
    esac

    if (( max_lines > 0 )); then
      bar_len=$(( count * bar_max / max_lines ))
    else
      bar_len=0
    fi
    (( bar_len == 0 && count > 0 )) && bar_len=1

    bar=""
    for (( i=0; i<bar_len; i++ )); do bar+="█"; done

    # Truncate long filenames
    local display_name="$f"
    if (( ${#f} > max_name_len )); then
      display_name="…${f: -$((max_name_len - 1))}"
    fi

    printf "  %${max_name_len}s  %6d  ${color}%s${reset}\n" "$display_name" "$count" "$bar"
  done

  printf "  %${max_name_len}s  %6s\n" "$(printf '%0.s─' {1..$max_name_len})" "──────"
  printf "  %${max_name_len}s  ${dim}%6d${reset}  ${dim}(%d files)${reset}\n\n" "Total" "$total_lines" "${#line_counts}"
}

# --------------------------------------------------------------------
# dotadd - Add a config file to the stow-managed dotfiles repo
# Usage: dotadd <file-or-dir> [app-name]
# --------------------------------------------------------------------
dotadd() {
  if [[ "$1" == "--help" || "$1" == "-h" || -z "$1" ]]; then
    cat <<'EOF'
Usage: dotadd <file-or-dir> [app-name]

Move a config file into ~/dotfiles and symlink it back via stow.

  <file-or-dir>  Path to the config file or directory
  [app-name]     Stow package name (auto-derived from ~/.config/<app>/...)

Examples:
  dotadd ~/.config/lazygit/config.yml     # app name inferred as 'lazygit'
  dotadd ~/.tmux.conf tmux                # app name required for ~/ dotfiles
  dotadd ~/.config/starship.toml starship  # override inferred name
EOF
    return 0
  fi

  local file="$1"
  local app="$2"

  # Resolve to absolute path
  file="${file/#\~/$HOME}"
  [[ "$file" != /* ]] && file="$PWD/$file"

  # Validate
  [[ ! -e "$file" ]] && echo "error: $file does not exist" && return 1
  [[ -L "$file" ]] && echo "error: $file is already a symlink (already stowed?)" && return 1

  # Auto-derive app name from ~/.config/<app>/...
  local rel="${file#$HOME/}"
  if [[ -z "$app" ]]; then
    if [[ "$rel" == .config/* ]]; then
      app=$(echo "$rel" | cut -d/ -f2)
    else
      echo "error: can't infer app name from $file, pass it as second arg"
      echo "  dotadd $1 <app-name>"
      return 1
    fi
  fi

  local dest="$HOME/dotfiles/$app/$rel"

  # Preview
  echo "move: $file -> $dest"
  echo "link: $file -> (symlink via stow $app)"
  read -q "?proceed? [y/N] " || { echo; return 1; }
  echo

  # Execute
  mkdir -p "$(dirname "$dest")"
  mv "$file" "$dest"
  (cd ~/dotfiles && stow "$app")
  echo "done: $app stowed"
}

# --------------------------------------------------------------------
# count-token - Estimate token count of files/directories (English text, no deps)
# Implemented in ~/.config/scripts/count-token (Python)
# --------------------------------------------------------------------
count-token() {
  /opt/homebrew/bin/python3.14 ~/.config/scripts/count-token "$@"
}

# --------------------------------------------------------------------
# agents - Attach to (or create) the long-lived "agents" tmux session
# used for remote access from the phone via mosh + Tailscale.
#
# The session always contains a "caffeinate" window running
#   caffeinate -dimsu
# (no child command — caffeinate without a child or -t blocks forever
# until killed). This keeps the Mac awake exactly as long as the
# window exists. Killing the session (or the window) lets the Mac
# sleep again on its idle timer.
#
# Usage: agents
# --------------------------------------------------------------------
agents() {
  if ! tmux has-session -t agents 2>/dev/null; then
    tmux new-session -d -s agents -n caffeinate 'exec caffeinate -dimsu'
    tmux new-window -t agents: -n shell
    tmux select-window -t agents:shell
  else
    # Self-heal: if the caffeinate window was closed by hand (or died),
    # recreate it. Otherwise the Mac would silently sleep on its idle
    # timer the next time you walked away.
    if ! tmux list-windows -t agents -F '#W' 2>/dev/null | grep -qx caffeinate; then
      tmux new-window -d -t agents: -n caffeinate 'exec caffeinate -dimsu'
    fi
  fi
  if [[ -n "$TMUX" ]]; then
    tmux switch-client -t agents
  else
    tmux attach -t agents
  fi
}

# --------------------------------------------------------------------
# agents-status - Show what's running inside the agents session
# --------------------------------------------------------------------
agents-status() {
  if ! tmux has-session -t agents 2>/dev/null; then
    echo "agents session: not running"
    echo "Mac is free to sleep on its idle timer."
    return 0
  fi

  echo "agents session: running"
  echo
  echo "Windows:"
  tmux list-windows -t agents -F '  #I  #W  (#{pane_current_command})'
  echo

  # Check the agents session specifically — not any caffeinate process
  # system-wide. The window must be named "caffeinate" AND its pane must
  # actually be running caffeinate (i.e., it didn't die and leave a shell).
  if tmux list-windows -t agents -F '#W #{pane_current_command}' 2>/dev/null \
       | grep -qx 'caffeinate caffeinate'; then
    echo "caffeinate: active (Mac will not sleep)"
  else
    echo "caffeinate: NOT active — run 'agents' to self-heal the window"
  fi
}

_loc_help() {
  cat <<'EOF'
Usage: loc [dir] [options]

Count lines per file (recursive) with a visual bar chart.
Respects .gitignore. Auto-ignores .claude, .agents, .agent,
.cursor, .git, .svn, node_modules.

Options:
  -m, --min <n>       Min lines to show (default: 200, use 0 for all)
  -s, --sort <key>    Sort by: size (default), name, ext
  -e, --ext <list>    Filter by extensions (comma-separated, e.g. py,js)
  -n, --limit <n>     Show only top N files
  -h, --help          Show this help

Examples:
  loc                     All files >= 200 lines, sorted by line count
  loc -m 0                All files, no minimum
  loc -m 500              Only files with 500+ lines
  loc src -e ts,tsx       Only TypeScript files in src/
  loc -n 15               Top 15 files by line count
EOF
}

