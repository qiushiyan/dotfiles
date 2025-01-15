return {
  {
    "mrcjkb/rustaceanvim",
    opts = {
      server = {
        default_settings = {
          ["rust-analyzer"] = {
            files = {
              excludeDirs = {
                "srcts/node_modules",
                "srcts/.next",
                ".next",
              },
            },
          },
        },
      },
    },
  },
}
