return {
  "saghen/blink.cmp",
  opts = {
    sources = {
      default = { "lsp", "snippets", "path", "buffer" },
    },
    completion = {
      menu = {
        border = "single",
        draw = {
          columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "kind" } },
        },
      },
      documentation = {
        window = { border = "single" },
      },
    },
  },
}
