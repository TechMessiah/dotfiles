return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed, {
        "vtsls",
        "rust-analyzer",
        "clangd",
        "pyright",
        "ruff",
        "sqls",
        "prettierd",
        "prettier",
        "clang-format",
        "sql-formatter",
      })
    end,
    -- Copied from LazyVim (lazyvim/plugins/lsp/init.lua) with the install
    -- check deferred. mason loads as a dependency of nvim-lspconfig, i.e. on
    -- BufReadPre, and mason-registry.refresh() is synchronous (~31ms) with
    -- another ~19ms for the is_installed() loop -- ~50ms on the critical path
    -- of every file open, just to confirm installed tools are still
    -- installed. mason.setup() stays synchronous because it puts the mason
    -- bin dir on PATH, which LSP startup needs.
    -- Re-sync this if LazyVim changes its own mason config.
    config = function(_, opts)
      require("mason").setup(opts)
      local mr = require("mason-registry")
      mr:on("package:install:success", function()
        vim.defer_fn(function()
          -- trigger FileType event to possibly load this newly installed LSP server
          require("lazy.core.handler.event").trigger({
            event = "FileType",
            buf = vim.api.nvim_get_current_buf(),
          })
        end, 100)
      end)

      vim.defer_fn(function()
        mr.refresh(function()
          for _, tool in ipairs(opts.ensure_installed) do
            local p = mr.get_package(tool)
            if not p:is_installed() then
              p:install()
            end
          end
        end)
      end, 2000)
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        sqls = {},
      },
      setup = {
        sqls = function(_, opts)
          local ok, _ = pcall(require, "sqls")
          if ok then
            require("sqls").setup({})
          end
          return false
        end,
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.diagnostics = opts.diagnostics or {}
      opts.diagnostics.float = { border = "single" }

      Snacks.util.lsp.on({ name = "vtsls" }, function(buffer, client)
        vim.api.nvim_create_autocmd("BufWritePre", {
          buffer = buffer,
          callback = function()
            -- Skip on the debounced autosave in config/autocmds.lua, which
            -- clears b:autoformat for the duration of its write. Organizing
            -- imports mid-edit costs an LSP round trip and applies a
            -- workspace edit under the cursor. `<leader>oi` does it on demand.
            if vim.b[buffer].autoformat == false then
              return
            end
            vim.lsp.buf.execute_command({
              command = "vtsls.commands.organizeImports",
              arguments = { vim.api.nvim_buf_get_name(buffer) },
            })
          end,
        })
      end)
      return opts
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.inlay_hints = opts.inlay_hints or {}
      return opts
    end,
    init = function()
      local lsp_hover_config = {
        border = "single",
        max_width = 80,
        max_height = 20,
      }
      vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, lsp_hover_config)
      vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
        vim.lsp.handlers.signature_help,
        { border = "single" }
      )
    end,
  },
}
