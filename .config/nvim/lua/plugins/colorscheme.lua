return {
  {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("onedark").setup({
        style = "dark",
        transparent = true,
        code_style = {
          comments = "italic",
          keywords = "bold",
          functions = "none",
          strings = "none",
          variables = "none",
        },
        highlights = {
          NormalFloat = { bg = "#1e2125" },
          FloatBorder = { bg = "#1e2125" },
          Pmenu = { bg = "#1e2125" },
          PmenuSel = { bg = "#3e4451" },
          PmenuSbar = { bg = "#1e2125" },
          PmenuThumb = { bg = "#3e4451" },
          NoiceCmdlinePopup = { bg = "#1e2125" },
          NoiceCmdlinePopupBorder = { bg = "#1e2125" },
          LineNr = { fg = "#3e4451" },
          CursorLineNr = { fg = "#abb2bf" },
          SnacksNormal = { bg = "#1e2125" },
          SnacksNormalNC = { bg = "#1e2125" },
          SnacksPickerNormal = { bg = "#1e2125" },
          SnacksPickerBorder = { bg = "#1e2125" },
          SnacksPickerPrompt = { bg = "#1e2125" },
          SnacksPickerInput = { bg = "#1e2125" },
          SnacksExplorerNormal = { bg = "#1e2125" },
          SnacksExplorerBorder = { bg = "#1e2125" },
          SnacksBackdrop = { bg = "#000000" },
        },
      })
      require("onedark").load()
      vim.cmd("colorscheme onedark")
    end,
  },
}
