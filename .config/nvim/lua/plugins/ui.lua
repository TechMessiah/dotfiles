return {
  { "nvim-mini/mini.animate", enabled = false },
  { "declancm/cinnamon.nvim", enabled = false },

  {
    "akinsho/bufferline.nvim",
    opts = {
      options = {
        diagnostics = "nvim_lsp",
        show_buffer_close_icons = true,
        show_close_icon = false,
        color_icons = false,
        show_buffer_icons = false,
        separator_style = { "", "" },
        indicator = { style = "none" },
      },
      highlights = {
        fill = { bg = "NONE" },
        background = { bg = "NONE", fg = "#3e4451" },
        tab = { bg = "NONE", fg = "#3e4451" },
        tab_selected = { bg = "NONE", fg = "#abb2bf", bold = true },
        buffer = { bg = "NONE", fg = "#3e4451" },
        buffer_selected = { bg = "NONE", fg = "#abb2bf", bold = true },
        buffer_visible = { bg = "NONE", fg = "#3e4451" },
        duplicate = { bg = "NONE", fg = "#3e4451" },
        duplicate_selected = { bg = "NONE", fg = "#abb2bf" },
        duplicate_visible = { bg = "NONE", fg = "#3e4451" },
        modified = { bg = "NONE", fg = "#3e4451" },
        modified_selected = { bg = "NONE", fg = "#abb2bf" },
        modified_visible = { bg = "NONE", fg = "#3e4451" },
        separator = { bg = "NONE", fg = "NONE" },
        separator_selected = { bg = "NONE", fg = "NONE" },
        separator_visible = { bg = "NONE", fg = "NONE" },
        indicator_selected = { bg = "NONE" },
        close_button = { bg = "NONE", fg = "#3e4451" },
        close_button_visible = { bg = "NONE", fg = "#3e4451" },
        close_button_selected = { bg = "NONE", fg = "#abb2bf" },
      },
    },
  },
  {
    "folke/noice.nvim",
    opts = function(_, opts)
      opts.lsp = opts.lsp or {}
      opts.lsp.progress = { enabled = false }
      opts.lsp.override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
      }
      opts.presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
        inc_rename = true,
      }
      opts.views = vim.tbl_deep_extend("force", opts.views or {}, {
        popup = { border = { style = "single", padding = { 0, 1 } } },
        cmdline_popup = { border = { style = "single", padding = { 0, 1 } } },
        confirm = { border = { style = "single", padding = { 0, 1 } } },
      })
      return opts
    end,
  },
  {
    "folke/which-key.nvim",
    opts = {
      win = { border = "single", padding = { 1, 2 } },
    },
  },
}
