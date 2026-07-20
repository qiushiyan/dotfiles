-- Slash-command completion for Claude Code's Ctrl+G prompt buffers.
-- The source (lua/claude-prompt/source.lua) only activates in buffers named
-- claude-prompt-*.md, so registering it globally is harmless elsewhere.
return {
  "saghen/blink.cmp",
  opts = {
    sources = {
      default = { "claude_skills" },
      providers = {
        claude_skills = {
          name = "ClaudeSkills",
          module = "claude-prompt.source",
          score_offset = 100,
        },
      },
    },
  },
}
