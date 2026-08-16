return {
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    local icons = LazyVim.config.icons

    local fg = "#5c6370"
    local clear = { bg = "NONE", fg = fg }
    local theme = {}
    for _, mode in ipairs({ "normal", "insert", "visual", "replace", "command", "terminal", "inactive" }) do
      theme[mode] = { a = clear, b = clear, c = clear, x = clear, y = clear, z = clear }
    end
    opts.options.theme = theme
    opts.options.globalstatus = true
    opts.options.component_separators = { left = "", right = "" }
    opts.options.section_separators = { left = "", right = "" }
    opts.options.disabled_filetypes = {
      statusline = { "dashboard", "alpha", "ministarter", "snacks_dashboard" },
    }
    opts.winbar = {}
    opts.inactive_winbar = {}

    opts.sections.lualine_a = {
      {
        "mode",
        color = { fg = "#61afef", gui = "bold" },
        fmt = function(str) return string.upper(str) end,
      },
    }
    opts.sections.lualine_b = { "branch" }
    opts.sections.lualine_c = {
      {
        "diagnostics",
        symbols = {
          error = icons.diagnostics.Error,
          warn = icons.diagnostics.Warn,
          info = icons.diagnostics.Info,
          hint = icons.diagnostics.Hint,
        },
      },
    }
    opts.sections.lualine_x = {
      function()
        local clients = vim.lsp.get_clients({ bufnr = 0 })
        if #clients == 0 then
          return " "
        end
        local names = vim.tbl_map(function(c)
          return c.name
        end, clients)
        return " " .. table.concat(names, ", ")
      end,
    }
    opts.sections.lualine_y = {
      {
        function()
          local file = vim.fn.expand("%:t")
          if file == "" then
            return ""
          end
          local root = LazyVim.root.get()
          local root_name = vim.fn.fnamemodify(root, ":t")
          return " " .. file .. "/" .. root_name .. " "
        end,
      },
    }
    opts.sections.lualine_z = {}

    return opts
  end,
}
