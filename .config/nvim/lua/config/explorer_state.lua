-- Persists the snacks explorer's `hidden` / `ignored` toggles across pickers
-- and across nvim sessions. Snacks regenerates its own `toggle_hidden` /
-- `toggle_ignored` actions on every picker open (see
-- snacks/picker/config/init.lua), so they can't be overridden by name --
-- we bind our own actions to the keys instead.
local M = {}

local file = vim.fs.joinpath(vim.fn.stdpath("state"), "snacks-explorer-toggles.json")

local defaults = { hidden = true, ignored = true }

local state = nil

local function load()
  if state then
    return state
  end
  state = vim.deepcopy(defaults)
  local ok, contents = pcall(vim.fn.readfile, file)
  if ok and contents[1] then
    local decoded_ok, decoded = pcall(vim.json.decode, table.concat(contents, "\n"))
    if decoded_ok and type(decoded) == "table" then
      for key in pairs(defaults) do
        if type(decoded[key]) == "boolean" then
          state[key] = decoded[key]
        end
      end
    end
  end
  return state
end

local function save()
  pcall(vim.fn.writefile, { vim.json.encode(load()) }, file)
end

-- `config` hook on the explorer source: runs on every picker open, after the
-- config tables are merged, so it's the last word on the initial toggle state.
-- It replaces the default explorer hook, so chain that one first.
function M.apply(opts)
  opts = require("snacks.picker.source.explorer").setup(opts) or opts
  local current = load()
  opts.hidden = current.hidden
  opts.ignored = current.ignored
  return opts
end

---@param name "hidden"|"ignored"
function M.toggle(name)
  return function(picker)
    local current = load()
    current[name] = not picker.opts[name]
    picker.opts[name] = current[name]
    save()
    picker.list:set_target()
    picker:find()
  end
end

return M
