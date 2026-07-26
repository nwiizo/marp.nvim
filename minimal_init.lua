-- Minimal init.lua to test marp.nvim
-- Run with: nvim -u minimal_init.lua

local source = debug.getinfo(1, "S").source:sub(2)
local plugin_root = vim.fn.fnamemodify(source, ":p:h")
vim.opt.runtimepath:prepend(plugin_root)

-- Print diagnostic info
vim.defer_fn(function()
  print("=== Minimal marp.nvim Test ===")
  print("Commands available:")
  if vim.fn.exists(":MarpWatch") == 2 then
    print("  ✓ :MarpWatch")
  else
    print("  ✗ :MarpWatch not found")
  end

  if vim.fn.exists(":MarpStop") == 2 then
    print("  ✓ :MarpStop")
  else
    print("  ✗ :MarpStop not found")
  end

  print("\nTry :checkhealth marp, then :MarpWatch on a markdown file")
end, 100)
