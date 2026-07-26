-- Luacheck configuration for marp.nvim

std = "lua51"

-- Ignore line length warnings
max_line_length = false

-- Global variables
globals = {
  "vim",
}

-- Ignore unused arguments
unused_args = false

-- Ignore unused loop variables
unused_secondaries = false

-- Specific ignores
ignore = {
  "212", -- Unused argument
  "213", -- Unused loop variable
}
