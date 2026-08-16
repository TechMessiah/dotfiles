return {
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
    },
    cmd = "Neogit",
    keys = {
      { "<leader>gg", "<cmd>Neogit<cr>", desc = "Neogit (Source Control)" },
      { "<leader>gb", "<cmd>Neogit branch<cr>", desc = "Git Branches" },
      { "<leader>gl", "<cmd>Neogit log<cr>", desc = "Git Log" },
    },
    opts = {
      graph_style = "unicode",
      integrations = { diffview = true },
      commit_editor = { kind = "split" },
      status = { recent_commit_count = 20 },
    },
  },

  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diff View (working tree)" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File History (current file)" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "File History (repo)" },
    },
    opts = {
      enhanced_diff_hl = true,
    },
  },
}
