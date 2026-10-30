# Brewfile — manually curated. Do NOT replace via `brew bundle dump`;
# that would re-introduce VS Code extensions and erase these section
# comments. Edit by hand instead.
#
# One file for every machine, split by ~/.config/machine:
#   every machine   the CLI toolchain the daily work needs on its own
#   desk            the machines a person sits at (mac, mini2): GUI apps, fonts
#   mini            what only the headless office mini runs
# A machine with no marker gets every machine's and the desk's set.
# `make brew` installs and never removes: a formula dropped here stays
# installed until `brew uninstall`.

MACHINE = begin
  File.read(File.expand_path("~/.config/machine")).strip
rescue Errno::ENOENT
  ""
end
DESK = MACHINE.empty? || %w[mac mini2].include?(MACHINE)

# === Taps ===
tap "hashicorp/tap"
tap "jandedobbeleer/oh-my-posh"
tap "qiushiyan/tap"
# local-only tap (no remote): `scripts/bootstrap.sh local_tap` creates it
# from docs/tmux-popupfix.rb — see docs/tmux-popup-patch.md
tap "qiushiyan/local"
tap "supabase/tap"

# === Shell & terminal ===
brew "bash"
brew "bat"
brew "bc"
brew "coreutils"
brew "difftastic"
brew "dust"
brew "fd"
brew "fzf"
brew "git-delta"
brew "jq"
brew "lazygit"
brew "macos-trash", link: true
brew "mole"
brew "moreutils", link: false
brew "mosh"
brew "neovim"
brew "openssh"
brew "pngpaste"   # nvim's image-aware Ctrl+V reads the pasteboard through it
brew "ripgrep"
brew "rsync"
brew "sesh"
brew "stow"
brew "tlrc"
# stock tmux replaced by qiushiyan/local/tmux-popupfix (3.7c + redraw fixes,
# see docs/tmux-popup-patch.md); revert to `brew "tmux"` once an upstream
# release after 3.7c passes that doc's harness
brew "qiushiyan/local/tmux-popupfix"
brew "trash"
brew "tree"
brew "unison"     # twin's reconciler; every machine runs the same version
brew "wget"
brew "zoxide"
brew "jandedobbeleer/oh-my-posh/oh-my-posh"

# === Languages & toolchains ===
brew "bun"
brew "go"
brew "node"
brew "nvm"
brew "python-setuptools"
brew "ruby", link: true
brew "uv"

# === Code tools ===
brew "ast-grep"
brew "cloc"
brew "cmake"
brew "git-filter-repo"
brew "git-lfs"
brew "gh"
brew "ruff"
brew "shellcheck"
brew "stylua"
brew "xcode-build-server"

# === Cloud, infra, dev services ===
brew "act"
brew "awscli"
brew "docker"
brew "hashicorp/tap/terraform"
brew "opentofu"
brew "pgbouncer"
brew "postgresql@16"
brew "postgresql@18", restart_service: :changed
brew "pgvector"   # planlab lanes; a postgresql upgrade can drop it
brew "protoc-gen-go"
brew "protoc-gen-go-grpc"
brew "supabase/tap/supabase"
brew "qiushiyan/tap/degit"

# === Media, docs, AI tooling ===
brew "ffmpeg"
brew "gnupg"
brew "graphviz"
brew "httpie"
brew "imagemagick"
brew "poppler"    # pdftotext, for planlab document reads
brew "yt-dlp"

# === CLI casks ===
cask "1password-cli"
cask "orbstack"

if MACHINE == "mini"
  brew "asimov"     # run by launchd-mini's com.qiushi.asimov, never brew services
  brew "tailscale"  # a system daemon, up before login (docs/qiushi-mini.md)
end

if DESK
  # === Desk: tools for a person at the screen ===
  brew "create-dmg"   # TabType's release script
  brew "duti"
  brew "herdr"
  brew "libimobiledevice"
  brew "mpv"
  brew "tectonic"
  brew "terminal-notifier"  # gazette-notify: a notification that opens the edition
  brew "whisper.cpp"

  # === Desk: GUI apps (casks) ===
  cask "1password"
  cask "arc"
  cask "chatgpt"
  cask "codex"
  cask "discord"
  cask "gcloud-cli"
  cask "ghostty"
  cask "google-chrome"
  cask "iina"
  cask "karabiner-elements"
  cask "linear"
  cask "microsoft-outlook"
  cask "microsoft-teams"
  cask "mongodb-compass"
  cask "raycast"
  cask "sf-symbols"
  cask "slack"
  cask "swiftformat-for-xcode"
  cask "tailscale-app"
  cask "thaw"
  cask "wechat"
  cask "xquartz"
  cask "zed"

  # === Desk: fonts ===
  cask "font-blex-mono-nerd-font"
  cask "font-cascadia-code"
  cask "font-code-new-roman-nerd-font"
  cask "font-comic-shanns-mono-nerd-font"
  cask "font-hack-nerd-font"
  cask "font-iosevka"
  cask "font-iosevka-term-nerd-font"
  cask "font-jetbrains-mono-nerd-font"
  cask "font-lxgw-wenkai"
  cask "font-maple-mono-nf-cn"
  cask "font-noto-color-emoji"
  cask "font-noto-emoji"
  cask "font-noto-nerd-font"
  cask "font-noto-sans-cjk-sc"
  cask "font-noto-serif-cjk-sc"
  cask "font-sarasa-gothic"
  cask "font-sf-mono"
  cask "font-sf-pro"
  cask "font-victor-mono-nerd-font"
end

# === Go binaries (installed via `go install`) ===
go "github.com/go-delve/delve/cmd/dlv"
go "github.com/segmentio/golines"
go "golang.org/x/tools/gopls"
go "sigs.k8s.io/kind"
go "github.com/tj/mmake/cmd/mmake"
go "go.uber.org/mock/mockgen"
go "golang.org/x/pkgsite/cmd/pkgsite"
go "google.golang.org/protobuf/cmd/protoc-gen-go"
go "honnef.co/go/tools/cmd/staticcheck"

# === Cargo binaries (installed via `cargo install`) ===
cargo "cargo-wasi"
cargo "deff"
cargo "trunk"
cargo "wasm-bindgen-cli"
