return {
  "RRethy/vim-illuminate",
  event = "LazyFile",
  opts = {
    delay = 200,
    -- no "regex": it re-scans the buffer 200ms after every cursor stop and
    -- is redundant once an LSP or treesitter parser is attached.
    providers = { "lsp", "treesitter" },
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
