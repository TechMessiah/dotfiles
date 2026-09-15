return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    opts = {
      panel = { enabled = false },
      suggestion = {
        enabled = true,
        auto_trigger = true,
        debounce = 75,
        keymap = {
          accept = "<M-l>",
          accept_word = "<M-w>",
          accept_line = "<M-L>",
          next = "<M-Right>",
          prev = "<M-Left>",
          dismiss = "<M-Esc>",
        },
      },
      filetypes = {
        markdown = true,
        gitcommit = true,
        help = false,
        gitrebase = false,
      },
    },
    config = function(_, opts)
      require("copilot").setup(opts)

      -- Make the right arrow friendly: accept Copilot when a suggestion is
      -- visible, otherwise keep its normal cursor-movement behavior.
      vim.keymap.set("i", "<Right>", function()
        local suggestion = require("copilot.suggestion")
        if suggestion.is_visible() then
          suggestion.accept()
          return ""
        end
        return "<Right>"
      end, {
        desc = "Accept Copilot suggestion or move right",
        expr = true,
        replace_keycodes = true,
        silent = true,
      })
    end,
  },
}
