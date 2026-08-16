local map = LazyVim.safe_keymap_set

-- File Explorer
map("n", "<C-e>", function()
  Snacks.explorer()
end, { desc = "Toggle File Explorer" })

-- Explorer keymaps (when in explorer):
-- a: create file/folder, d: delete, r: rename, c: copy, m: move, y: yank, <C-x>: cut

map("n", "<leader>te", function()
  local dir = vim.fn.expand("%:p:h")
  vim.fn.jobstart(
    { "xdg-terminal-exec", "bash", "-c", "cd " .. vim.fn.shellescape(dir) .. " && exec $SHELL" },
    { detach = true }
  )
end, { desc = "Open terminal at current dir" })

-- Glow preview for markdown (buffer-local, .md only)
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function(ev)
    if not vim.api.nvim_buf_get_name(ev.buf):match("%.md$") then
      return
    end
    vim.keymap.set("n", "<leader>mg", function()
      require("config.glow").open(vim.api.nvim_buf_get_name(ev.buf))
    end, { buffer = ev.buf, desc = "Preview in Glow" })
  end,
})

map("n", "<leader>rr", function()
  local file = vim.fn.expand("%:p")
  local ft = vim.bo.filetype
  local cmd
  if ft == "python" then
    cmd = "python3 " .. vim.fn.shellescape(file)
  elseif ft == "c" then
    local out = vim.fn.tempname()
    cmd = "cc " .. vim.fn.shellescape(file) .. " -o " .. out .. " && " .. out
  elseif ft == "cpp" then
    local out = vim.fn.tempname()
    cmd = "c++ -std=c++20 " .. vim.fn.shellescape(file) .. " -o " .. out .. " && " .. out
  elseif ft == "rust" then
    local root = vim.fs.root(0, "Cargo.toml")
    if root then
      cmd = "cd " .. vim.fn.shellescape(root) .. " && cargo run"
    else
      local out = vim.fn.tempname()
      cmd = "rustc " .. vim.fn.shellescape(file) .. " -o " .. out .. " && " .. out
    end
  else
    vim.notify("No runner for filetype: " .. ft, vim.log.levels.WARN)
    return
  end
  vim.cmd.write()
  local dir = vim.fn.expand("%:p:h")
  local shell_cmd = "cd "
    .. vim.fn.shellescape(dir)
    .. " && "
    .. cmd
    .. '; printf "\\n[exit %s] press any key to close" "$?"; read -rsn1'
  vim.fn.jobstart({ "xdg-terminal-exec", "bash", "-c", shell_cmd }, { detach = true })
end, { desc = "Run current file" })

-- Toggle root discovery: on = lsp/.git/lua detection, off = always cwd
local root_spec_default = { "lsp", { ".git", "lua" }, "cwd" }
Snacks.toggle
  .new({
    id = "root_discovery",
    name = "Root Discovery",
    get = function()
      return not (type(vim.g.root_spec) == "table" and #vim.g.root_spec == 1 and vim.g.root_spec[1] == "cwd")
    end,
    set = function(state)
      vim.g.root_spec = state and root_spec_default or { "cwd" }
      LazyVim.root.cache = {}
      vim.cmd.redrawstatus()
    end,
  })
  :map("<leader>uR")

map("n", "<leader>oi", function()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  for _, client in ipairs(clients) do
    local server = client.name
    if server == "vtsls" then
      vim.lsp.buf.execute_command({
        command = "vtsls.commands.organizeImports",
        arguments = { vim.api.nvim_buf_get_name(bufnr) },
      })
      return
    end
    if server == "rust-analyzer" then
      vim.lsp.buf.code_action({ context = { only = { "source.organizeImports" } }, apply = true })
      return
    end
    if server == "ruff" then
      vim.lsp.buf.code_action({ context = { only = { "source.organizeImports.ruff" } }, apply = true })
      return
    end
  end
end, { desc = "Organize Imports" })
