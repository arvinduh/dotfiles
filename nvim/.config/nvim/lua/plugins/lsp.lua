-- LSP.
--
-- Four servers deliberately come from the SYSTEM rather than Mason, each from
-- the installer that already owns that language:
--   clangd        — apt. Mason's build links against a different glibc and then
--                   disagrees with your system headers. For C++ that is fatal.
--   rust-analyzer — rustup. Must match the toolchain or it drifts on edition
--                   and nightly features.
--   basedpyright  — uv. Mason builds it in a stdlib venv, which needs the
--                   python3-venv apt package; uv brings its own Python and
--                   needs nothing. One installer owns Python, not two.
--   ruff          — uv. Same reason, and it lands on $PATH so `ruff check`
--                   works in the shell too, not only inside the editor.
-- See the README bootstrap.

return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      { "mason-org/mason.nvim", opts = { ui = { border = "rounded" } } },
      { "mason-org/mason-lspconfig.nvim" },
    },
    config = function()
      -- ---- diagnostics ------------------------------------------------------
      vim.diagnostic.config({
        virtual_text = { spacing = 2, prefix = "●", source = "if_many" },
        severity_sort = true,
        underline = true,
        update_in_insert = false,
        float = { border = "rounded", source = true },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN] = " ",
            [vim.diagnostic.severity.HINT] = " ",
            [vim.diagnostic.severity.INFO] = " ",
          },
        },
      })

      -- ---- keymaps, bound only where a server actually attached -------------
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("dot_lsp_attach", { clear = true }),
        callback = function(ev)
          local function map(keys, fn, desc, mode)
            vim.keymap.set(mode or "n", keys, fn, { buffer = ev.buf, desc = "LSP: " .. desc })
          end
          local fzf = require("fzf-lua")

          map("gd", fzf.lsp_definitions, "Definitions")
          map("gr", fzf.lsp_references, "References")
          map("gI", fzf.lsp_implementations, "Implementations")
          map("gy", fzf.lsp_typedefs, "Type definitions")
          map("gD", vim.lsp.buf.declaration, "Declaration")
          map("K", vim.lsp.buf.hover, "Hover")
          map("<leader>cr", vim.lsp.buf.rename, "Rename")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action", { "n", "v" })
          map("<leader>cs", fzf.lsp_document_symbols, "Document symbols")
          map("<leader>cS", fzf.lsp_live_workspace_symbols, "Workspace symbols")
          map("<C-s>", vim.lsp.buf.signature_help, "Signature help", "i")

          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          if client and client:supports_method("textDocument/inlayHint") then
            map("<leader>ch", function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
            end, "Toggle inlay hints")
          end
        end,
      })

      -- ---- capabilities (blink.cmp extends the defaults) --------------------
      local caps = require("blink.cmp").get_lsp_capabilities()
      vim.lsp.config("*", { capabilities = caps })

      -- ---- per-server settings ----------------------------------------------
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
            hint = { enable = true },
            diagnostics = { globals = { "vim" } },
            format = { enable = false }, -- stylua owns this
          },
        },
      })

      vim.lsp.config("basedpyright", {
        settings = {
          basedpyright = {
            analysis = {
              typeCheckingMode = "standard",
              autoImportCompletions = true,
              diagnosticSeverityOverrides = {
                -- ruff already reports these; avoid double-reporting.
                reportUnusedImport = "none",
                reportUnusedVariable = "none",
              },
            },
          },
        },
      })

      vim.lsp.config("ruff", {
        -- basedpyright owns hover; ruff owns lint + organise-imports.
        on_attach = function(client)
          client.server_capabilities.hoverProvider = false
        end,
      })

      vim.lsp.config("clangd", {
        cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--header-insertion=iwyu",
          "--completion-style=detailed",
          "--function-arg-placeholders",
          "--fallback-style=Google", -- matches ~/.clang-format
        },
        init_options = { fallbackFlags = { "-std=c++20" } },
      })

      vim.lsp.config("jsonls", {
        settings = {
          json = {
            -- SchemaStore gives completion + validation in package.json,
            -- tsconfig.json, GH Actions, and ~1000 others.
            schemas = require("schemastore").json.schemas(),
            validate = { enable = true },
          },
        },
      })

      vim.lsp.config("yamlls", {
        settings = {
          yaml = { schemaStore = { enable = false, url = "" }, schemas = require("schemastore").yaml.schemas() },
        },
      })

      -- ---- Mason installs the editor-side servers ---------------------------
      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls",
          "vtsls",
          "jsonls",
          "yamlls",
          "taplo",
          "marksman",
          -- basedpyright and ruff intentionally absent — see header.
          -- bashls omitted: shellcheck via nvim-lint already reports what
          -- matters in shell scripts, and does it without a server.
          -- clangd and rust_analyzer intentionally absent — see header.
        },
        automatic_enable = true,
      })

      -- System-provided servers, enabled directly.
      vim.lsp.enable({ "clangd", "rust_analyzer", "basedpyright", "ruff" })
    end,
  },

  { "b0o/schemastore.nvim", lazy = true },
}
