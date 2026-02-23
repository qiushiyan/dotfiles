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
    "R-nvim/R.nvim",
    lazy = false,
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.inlay_hints = { enabled = false }
      opts.servers.pyright = {}
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
          require("fzf-lua").lsp_document_symbols({ query = word })
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
        vtsls = {
          keys = {
            {
              "<leader>cu",
              LazyVim.lsp.action["source.removeUnused.ts"],
              desc = "Remove unused imports",
            },
          },
        },
        harper_ls = {
          enabled = true,
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
