return {
  "saghen/blink.cmp",
  dependencies = { "fang2hou/blink-copilot" },
  opts = {
    sources = {
      default = { "copilot", "lsp", "snippets", "path", "buffer" },
      providers = {
        copilot = {
          name = "copilot",
          module = "blink-copilot",
          score_offset = 100,
          async = true,
        },
      },
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
