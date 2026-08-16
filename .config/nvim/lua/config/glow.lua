local M = {}

--- Open a markdown file in glow inside a new terminal window
---@param path string? absolute or relative path to the file
function M.open(path)
  if not path or not path:match("%.md$") then
    vim.notify("Glow preview only works for .md files", vim.log.levels.WARN)
    return
  end
  if vim.fn.executable("glow") == 0 then
    vim.notify("glow is not installed or not in PATH", vim.log.levels.ERROR)
    return
  end
  vim.fn.jobstart({ "xdg-terminal-exec", "glow", "-p", path }, { detach = true })
end

return M
