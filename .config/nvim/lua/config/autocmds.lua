local bg = "#1e2125"

local set_highlights = function()
  vim.api.nvim_set_hl(0, "Normal", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "SignColumn", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "LineNr", { bg = "NONE", fg = "#3e4451" })
  vim.api.nvim_set_hl(0, "CursorLine", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "CursorLineNr", { bg = "NONE", fg = "#abb2bf" })
  vim.api.nvim_set_hl(0, "WinSeparator", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "StatusLine", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "StatusLineNC", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "MsgArea", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "ModeMsg", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "TabLine", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "TabLineFill", { bg = "NONE" })

  vim.api.nvim_set_hl(0, "NormalFloat", { bg = bg })
  vim.api.nvim_set_hl(0, "FloatBorder", { bg = bg })
  vim.api.nvim_set_hl(0, "Pmenu", { bg = bg })
  vim.api.nvim_set_hl(0, "PmenuSel", { bg = "#3e4451" })
  vim.api.nvim_set_hl(0, "PmenuSbar", { bg = bg })
  vim.api.nvim_set_hl(0, "PmenuThumb", { bg = "#3e4451" })
  vim.api.nvim_set_hl(0, "NoiceCmdlinePopup", { bg = bg })
  vim.api.nvim_set_hl(0, "NoiceCmdlinePopupBorder", { bg = bg })

  vim.api.nvim_set_hl(0, "SnacksNormal", { bg = bg })
  vim.api.nvim_set_hl(0, "SnacksNormalNC", { bg = bg })
  vim.api.nvim_set_hl(0, "SnacksPickerNormal", { bg = bg })
  vim.api.nvim_set_hl(0, "SnacksPickerBorder", { bg = bg })
  vim.api.nvim_set_hl(0, "SnacksPickerPrompt", { bg = bg })
  vim.api.nvim_set_hl(0, "SnacksPickerInput", { bg = bg })
  vim.api.nvim_set_hl(0, "SnacksExplorerNormal", { bg = bg })
  vim.api.nvim_set_hl(0, "SnacksExplorerBorder", { bg = bg })
  vim.api.nvim_set_hl(0, "SnacksBackdrop", { bg = "#000000" })
end

set_highlights()

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = set_highlights,
})

vim.api.nvim_create_autocmd("UIEnter", {
  callback = function()
    vim.schedule(set_highlights)
  end,
})

-- :q / :wq act on the current buffer only; quit nvim when it's the last listed buffer
local function smart_close(opts)
  if opts.write then
    vim.cmd("write")
  end
  if vim.bo.buftype ~= "" then
    -- special windows (help, terminal, etc): just close the window
    vim.cmd(opts.force and "quit!" or "quit")
    return
  end
  if #vim.fn.getbufinfo({ buflisted = 1 }) <= 1 then
    vim.cmd(opts.force and "qa!" or "qa")
  else
    Snacks.bufdelete({ force = opts.force })
  end
end

vim.api.nvim_create_user_command("SmartQuit", function(o)
  smart_close({ write = false, force = o.bang })
end, { bang = true })

vim.api.nvim_create_user_command("SmartWq", function(o)
  smart_close({ write = true, force = o.bang })
end, { bang = true })

vim.cmd([[
  cnoreabbrev <expr> q (getcmdtype() == ':' && getcmdline() ==# 'q') ? 'SmartQuit' : 'q'
  cnoreabbrev <expr> wq (getcmdtype() == ':' && getcmdline() ==# 'wq') ? 'SmartWq' : 'wq'
]])

local autosave_timer = nil

vim.api.nvim_create_autocmd("TextChanged", {
  callback = function()
    if not vim.bo.modified or vim.bo.buftype ~= "" or vim.fn.expand("%") == "" then
      return
    end
    if autosave_timer then
      autosave_timer:stop()
    end
    autosave_timer = vim.defer_fn(function()
      autosave_timer = nil
      if vim.bo.modified then
        vim.cmd("silent! write")
      end
    end, 500)
  end,
})
