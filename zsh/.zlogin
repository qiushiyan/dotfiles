# Login profiles (including macOS path_helper and Homebrew) can reorder PATH.
if [[ -f "$HOME/.config/zsh/toolchain.zsh" ]]; then
  source "$HOME/.config/zsh/toolchain.zsh"
fi
