-- Formatting.
--
-- conform dispatches to the CLI formatters configured globally in
-- ~/.editorconfig, ~/.clang-format, ~/.config/ruff/ruff.toml etc. Those all
-- resolve by walking up parent directories, so a project with its own config
-- automatically wins over your globals — nothing to toggle.
--
-- :FormatToggle  turn format-on-save off for this buffer (or ! for globally).
-- You WILL need this the first time you open a repo whose style you must not
-- touch; without it you will fight your own config inside a PR diff.

return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo", "Format" },
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_format = "fallback" })
        end,
        mode = { "n", "v" },
        desc = "Format buffer",
      },
    },
    opts = {
      formatters_by_ft = {
        python = { "ruff_format", "ruff_organize_imports" },
        cpp = { "clang_format" },
        c = { "clang_format" },
        rust = { "rustfmt" },
        -- Prettier covers TS, JSON, Markdown and YAML. Biome would be faster
        -- and cover the first two, but at file-save scale that is invisible,
        -- and two JS-ecosystem formatters is one config file too many.
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        json = { "prettier" },
        jsonc = { "prettier" },
        markdown = { "prettier" },
        yaml = { "prettier" },
        toml = { "taplo" },
        lua = { "stylua" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        zsh = { "shfmt" },
        ["_"] = { "trim_whitespace" }, -- fallback for everything else
      },

      format_on_save = function(bufnr)
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
          return
        end
        return { timeout_ms = 1000, lsp_format = "fallback" }
      end,

      formatters = {
        -- --search-parent-directories is what makes ~/.config/stylua/stylua.toml
        -- act as the global fallback.
        stylua = { prepend_args = { "--search-parent-directories" } },
        shfmt = { prepend_args = { "-i", "2", "-ci", "-bn" } },
        clang_format = { prepend_args = { "--style=file", "--fallback-style=Google" } },
      },
    },
    init = function()
      vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

      vim.api.nvim_create_user_command("FormatToggle", function(args)
        if args.bang then
          vim.g.disable_autoformat = not vim.g.disable_autoformat
          vim.notify("format-on-save " .. (vim.g.disable_autoformat and "OFF" or "ON") .. " (global)")
        else
          vim.b.disable_autoformat = not vim.b.disable_autoformat
          vim.notify("format-on-save " .. (vim.b.disable_autoformat and "OFF" or "ON") .. " (buffer)")
        end
      end, { desc = "Toggle format-on-save", bang = true })
    end,
  },

  -- Linters that are not language servers: markdownlint for Markdown
  -- STRUCTURE (Prettier only handles layout and cannot report problems),
  -- plus shellcheck.
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost", "InsertLeave" },
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        markdown = { "markdownlint-cli2" },
        sh = { "shellcheck" },
        bash = { "shellcheck" },
      }
      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
        group = vim.api.nvim_create_augroup("dot_lint", { clear = true }),
        callback = function()
          require("lint").try_lint()
        end,
      })
    end,
  },

  -- mason-lspconfig's ensure_installed covers language SERVERS only. These
  -- three are plain CLI tools that conform and nvim-lint call by name, so
  -- without this nothing installs them and format-on-save silently no-ops.
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    -- lazy.lua sets defaults.lazy = true, so without a trigger this plugin
    -- would never load and would install nothing at all.
    event = "VeryLazy",
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      ensure_installed = { "prettier", "stylua", "markdownlint-cli2" },
      run_on_start = true,
    },
  },
}
