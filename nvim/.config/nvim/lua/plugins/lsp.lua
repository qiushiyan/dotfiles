local border = {
  { "🭽", "FloatBorder" },
  { "▔", "FloatBorder" },
  { "🭾", "FloatBorder" },
  { "▕", "FloatBorder" },
  { "🭿", "FloatBorder" },
  { "▁", "FloatBorder" },
  { "🭼", "FloatBorder" },
  { "▏", "FloatBorder" },
}

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.inlay_hints = { enabled = false }
      opts.filetype_opts = {
        typescriptreact = {
          spell = true,
        },
      }
      local on_publish_diagnostics = vim.lsp.diagnostic.on_publish_diagnostics
      opts.servers.bashls = vim.tbl_deep_extend("force", opts.servers.bashls or {}, {
        handlers = {
          ["textDocument/publishDiagnostics"] = function(err, res, ...)
            local file_name = vim.fn.fnamemodify(vim.uri_to_fname(res.uri), ":t")
            if string.match(file_name, "^%.env") == nil then
              return on_publish_diagnostics(err, res, ...)
            end
          end,
        },
      })

      -- tsc (the TypeScript 7 native server, LazyVim's "tsgo" choice): skip
      -- lspconfig's binary probe. Its root_dir runs `--version` on
      -- <root>/node_modules/.bin/tsc, then on `tsc` from PATH, blocking until
      -- one reports 7+: in a project pinning TS 5 (planlab) that is ~70ms
      -- before each project's first TS file draws, only to settle on Mason's
      -- copy anyway. This uses Mason's tsc directly and keeps lspconfig's Deno
      -- detection, which only walks the tree (planlab's repos/effect has a
      -- deno.json beside its pnpm lock, and tsc stays out of it).
      -- Tradeoff: a project pinning TS 7+ in node_modules gets Mason's tsc,
      -- not its own.
      local mason_tsc = vim.fn.stdpath("data") .. "/mason/bin/tsc"
      opts.servers.tsc = vim.tbl_deep_extend("force", opts.servers.tsc or {}, {
        cmd = function(dispatchers)
          local bin = vim.fn.executable(mason_tsc) == 1 and mason_tsc or "tsc"
          return vim.lsp.rpc.start({ bin, "--lsp", "--stdio" }, dispatchers)
        end,
        -- lspconfig's lsp/tsc.lua root logic, minus the probe
        root_dir = function(bufnr, on_dir)
          local locks = { "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" }
          local project_root = vim.fs.root(bufnr, { locks, ".git" })
          local deno_root = vim.fs.root(bufnr, { "deno.json", "deno.jsonc" })
          local deno_lock_root = vim.fs.root(bufnr, "deno.lock")
          if deno_lock_root and (not project_root or #deno_lock_root > #project_root) then
            return -- deno.lock is closer than the package manager lock
          end
          if deno_root and (not project_root or #deno_root >= #project_root) then
            return -- deno.json is at least as close as the package manager lock
          end
          on_dir(project_root or vim.fn.getcwd())
        end,
      })

      opts.servers.tailwindcss = {
        root_dir = function(fname)
          -- 1. Guard against fname being a number or an empty string.
          if type(fname) ~= "string" or fname == "" then
            return nil
          end

          -- 2. Safely find the package.json file.
          local found_files = vim.fs.find("package.json", { path = fname, upward = true })

          -- 3. Check that the file was actually found before proceeding.
          if not found_files or #found_files == 0 then
            return nil
          end

          -- The rest of your logic remains, but is now safer.
          local package_json_dir = vim.fs.dirname(found_files[1])
          local full_path = package_json_dir .. "/package.json"

          local file = io.open(full_path, "r")
          if not file then
            return nil
          end

          local content = file:read("*a")
          file:close()

          if content and content:match('"tailwindcss"%s*:') then
            return package_json_dir
          end

          return nil
        end,
      }
    end,
    keys = {
      {
        "gh",
        function()
          return vim.lsp.buf.hover()
        end,
        desc = "Hover",
      },
      {
        "gR",
        function()
          local word = vim.fn.expand("<cword>")
          Snacks.picker.lsp_symbols({ pattern = word })
        end,
        desc = "References (current buffer)",
        nowait = true,
      },
      {
        "gt",
        function()
          Snacks.picker.lsp_type_definitions()
        end,
        desc = "Goto Type Definition",
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        harper_ls = {
          enabled = false,
          filetypes = { "markdown" },
          settings = {
            ["harper-ls"] = {
              userDictPath = "~/.config/nvim/spell/en.utf-8.add",
              linters = {
                ToDoHyphen = false,
                -- SentenceCapitalization = true,
                -- SpellCheck = true,
              },
              isolateEnglish = true,
              markdown = {
                -- [ignores this part]()
                -- [[ also ignores my marksman links ]]
                IgnoreLinkTitle = true,
              },
            },
          },
        },
      },
    },
  },
}
