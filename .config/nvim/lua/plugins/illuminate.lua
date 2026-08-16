return {
  "RRethy/vim-illuminate",
  event = "LazyFile",
  opts = {
    delay = 200,
    providers = { "lsp", "treesitter", "regex" },
  },
  config = function(_, opts)
    require("illuminate").configure(opts)
  end,
  keys = {
    {
      "]]",
      function()
        require("illuminate").goto_next_reference()
      end,
      desc = "Next Reference",
    },
    {
      "[[",
      function()
        require("illuminate").goto_prev_reference()
      end,
      desc = "Prev Reference",
    },
  },
}
