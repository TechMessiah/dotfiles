require("config.remote_clipboard").setup()
-- Directory nvim was launched from, before any root-detection/cd kicks in
vim.g.launch_cwd = vim.fn.getcwd()

vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.smoothscroll = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.undofile = true
vim.opt.sessionoptions = "buffers,curdir,folds,help,tabpages,winsize,winpos,terminal"
vim.opt.autowrite = true

vim.opt.fillchars = { eob = " ", foldopen = "", foldclose = "", fold = " ", diff = "╱", vert = "╱" }
vim.opt.signcolumn = "yes:1"
vim.opt.numberwidth = 2
vim.opt.title = true
vim.opt.winborder = "single"
