-- Debug script to check why marp.nvim commands aren't loading

print("=== marp.nvim Debug Information ===\n")

-- Check if plugin is in runtimepath
print("1. Checking runtimepath:")
local found = false
for _, path in ipairs(vim.api.nvim_list_runtime_paths()) do
  if path:match("marp%.nvim") then
    print("  ✓ Found in runtimepath: " .. path)
    found = true
  end
end
if not found then
  print("  ✗ marp.nvim NOT found in runtimepath!")
end

-- Check if plugin/marp.vim was sourced
print("\n2. Checking if plugin was loaded:")
if vim.g.loaded_marp then
  print("  ✓ g:loaded_marp is set (plugin loaded)")
else
  print("  ✗ g:loaded_marp is NOT set (plugin not loaded)")
end

-- Check if commands exist
print("\n3. Checking commands:")
local commands = {"MarpWatch", "MarpStop", "MarpPreview", "MarpExport"}
for _, cmd in ipairs(commands) do
  local exists = vim.fn.exists(":" .. cmd) == 2
  if exists then
    print("  ✓ :" .. cmd .. " exists")
  else
    print("  ✗ :" .. cmd .. " does NOT exist")
  end
end

-- Check if Lua module can be loaded
print("\n4. Checking Lua module:")
local ok, marp = pcall(require, "marp")
if ok then
  print("  ✓ require('marp') successful")
  if marp.setup then
    print("  ✓ marp.setup function exists")
  else
    print("  ✗ marp.setup function missing")
  end
else
  print("  ✗ require('marp') failed: " .. tostring(marp))
end

-- Check _G._marp_initialized
print("\n5. Checking initialization:")
if _G._marp_initialized then
  print("  ✓ _G._marp_initialized is true")
else
  print("  ✗ _G._marp_initialized is false/nil")
end

-- Suggest fixes
print("\n=== Suggestions ===")
if not found then
  print("• Add plugin to your plugin manager configuration")
  print("• Or manually add to runtimepath:")
  print("  vim.opt.rtp:append('/Users/nwiizo/ghq/github.com/nwiizo/marp.nvim')")
end

if not vim.g.loaded_marp then
  print("• Try manually sourcing the plugin:")
  print("  :source /Users/nwiizo/ghq/github.com/nwiizo/marp.nvim/plugin/marp.vim")
end

print("\n=== Manual Test ===")
print("Try running this command to manually load the plugin:")
print(":lua vim.opt.rtp:append('/Users/nwiizo/ghq/github.com/nwiizo/marp.nvim'); vim.cmd('runtime! plugin/**/*.vim')")