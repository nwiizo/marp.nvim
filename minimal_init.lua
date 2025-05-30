-- Minimal init.lua to test marp.nvim
-- Run with: nvim -u minimal_init.lua

-- Add the plugin to runtimepath
vim.opt.rtp:append('/Users/nwiizo/ghq/github.com/nwiizo/marp.nvim')

-- Source all plugin files
vim.cmd('runtime! plugin/**/*.vim')

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
  
  print("\nTry running :MarpWatch on a markdown file")
end, 100)