# Disabled Plugins

This directory contains plugin configurations that are disabled but kept for reference.

## Contents

- **avante.lua** - AI integration using Ollama (disabled: experimenting with alternatives)
- **codecompanion.lua** - Alternative AI assistant with Qwen adapter (disabled: experimenting with alternatives)
- **nvim-cmp.lua** - Completion engine (disabled: superseded by blink-cmp)
- **auto-save.lua** - Auto-save with visual mode and flash.nvim integration (disabled: caused issues with certain workflows)

## Re-enabling

To re-enable a plugin:
1. Move the file back to `lua/plugins/`
2. Set `enabled = true` in the plugin spec (or remove the `enabled = false` line)
3. Run `:Lazy sync`
