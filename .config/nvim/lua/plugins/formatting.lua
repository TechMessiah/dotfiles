-- The prettier CLI reloads every parser per invocation: measured 3.0-9.4s on a
-- 1200-line .ts file, which times out at any sane limit. prettierd keeps a
-- daemon warm and does the same file in ~1s with byte-identical output.
-- prettier stays as a fallback for when the daemon isn't running.
local prettier_fts =
  { "javascript", "typescript", "javascriptreact", "typescriptreact", "html", "css", "json", "markdown" }
local prettier = { "prettierd", "prettier", stop_after_first = true }

local formatters_by_ft = {
  python = { "ruff_format" },
  rust = { "rustfmt" },
  c = { "clang-format" },
  cpp = { "clang-format" },
  sql = { "sql-formatter" },
  lua = { "stylua" },
}
for _, ft in ipairs(prettier_fts) do
  formatters_by_ft[ft] = prettier
end

return {
  {
    "stevearc/conform.nvim",
    init = function()
      -- Cold-starting the prettierd daemon takes ~5s, on its own enough to
      -- trip the format timeout on the first :w of a session. Start it in the
      -- background when the first prettier-handled file is opened, so it is up
      -- well before anything asks it to format. Deferred past FileType so
      -- mason has put its bin dir on PATH.
      vim.api.nvim_create_autocmd("FileType", {
        pattern = prettier_fts,
        once = true,
        callback = function()
          vim.defer_fn(function()
            local exe = vim.fn.exepath("prettierd")
            if exe ~= "" then
              vim.system({ exe, "start" })
            end
          end, 100)
        end,
      })
    end,
    opts = {
      formatters_by_ft = formatters_by_ft,
      -- LazyVim strips `format_on_save`/`format_after_save` and drives conform
      -- through its own formatter registry, so per-format options have to go
      -- here to take effect.
      default_format_opts = {
        -- Measured through conform with a warm daemon: a 300-line ts file is
        -- 0.3-1.1s and an already-formatted 4800-line one ~1.2s, but a large
        -- file that actually needs reflowing reached 2.9s -- enough to trip
        -- LazyVim's default 3000 and abort the format.
        timeout_ms = 5000,
        -- merge the format edits into the undo block of the change that
        -- triggered the write, so `u` doesn't step through formatting
        undojoin = true,
      },
    },
  },
}
