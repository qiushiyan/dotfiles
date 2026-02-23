local paths = require("config.paths")

return {
  "mfussenegger/nvim-lint",
  optional = true,
  opts = {
    linters = {
      ["markdownlint-cli2"] = {
        args = { "--config", paths.markdownlint_config, "--" },
      },
    },
  },
}
