return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    opts.explorer = vim.tbl_deep_extend("force", opts.explorer or {}, {
      replace_netrw = true,
    })

    -- Directory of the selected explorer item (item itself if dir, parent otherwise)
    local function item_dir(picker, item)
      if not item then
        return picker:cwd()
      end
      local path = Snacks.picker.util.path(item)
      return item.dir and path or vim.fs.dirname(path)
    end

    opts.picker = vim.tbl_deep_extend("force", opts.picker or {}, {
      layout = {
        backdrop = 60,
      },
      sources = {
        explorer = {
          layout = { preset = "default" },
          actions = {
            glow_preview = function(_, item)
              if item then
                require("config.glow").open(Snacks.picker.util.path(item))
              end
            end,
            search_files = function(picker, item)
              local dir = item_dir(picker, item)
              picker:close()
              Snacks.picker.files({ cwd = dir, hidden = true })
            end,
            search_grep = function(picker, item)
              local dir = item_dir(picker, item)
              picker:close()
              Snacks.picker.grep({ cwd = dir, hidden = true })
            end,
            explorer_launch_dir = function(picker)
              local dir = vim.g.launch_cwd or vim.uv.cwd()
              picker:close()
              vim.cmd.cd(dir)
              Snacks.explorer({ cwd = dir })
            end,
          },
          auto_close = true,
          jump = { close = true },
          follow_file = false,
          focus = "list",
          hidden = true,
          ignored = true,
          win = {
            list = {
              keys = {
                ["a"] = "explorer_add",
                ["d"] = "explorer_del",
                ["r"] = "explorer_rename",
                ["c"] = "explorer_copy",
                ["m"] = "explorer_move",
                ["y"] = "explorer_yank",
                ["H"] = "toggle_hidden",
                ["<leader>mg"] = "glow_preview",
                ["f"] = "search_files",
                ["s"] = "search_grep",
                [".."] = "explorer_launch_dir",
              },
            },
          },
        },
      },
    })

    opts.indent = { enabled = false }

    opts.dashboard = { enabled = false }

    return opts
  end,
}
