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
        "prettier",
        "clang-format",
        "sql-formatter",
      })
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
