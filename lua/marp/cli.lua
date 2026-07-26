local M = {}

-- Keep this list aligned with cosmiconfig's asynchronous default search places.
-- package.json is handled separately because only a top-level "marp" property
-- represents a Marp CLI configuration.
local config_places = {
  ".marprc",
  ".marprc.json",
  ".marprc.yaml",
  ".marprc.yml",
  ".marprc.js",
  ".marprc.ts",
  ".marprc.cjs",
  ".marprc.mjs",
  ".config/marprc",
  ".config/marprc.json",
  ".config/marprc.yaml",
  ".config/marprc.yml",
  ".config/marprc.js",
  ".config/marprc.ts",
  ".config/marprc.cjs",
  ".config/marprc.mjs",
  "marp.config.js",
  "marp.config.ts",
  "marp.config.cjs",
  "marp.config.mjs",
}

local function package_has_marp_config(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return false
  end

  local decode = vim.json and vim.json.decode or vim.fn.json_decode
  local decoded, package = pcall(decode, table.concat(lines, "\n"))
  return decoded and type(package) == "table" and package.marp ~= nil
end

-- Find the same project-level configuration that Marp CLI would discover.
-- Returns the config path (or nil) and the directory Marp should run from.
function M.find_config(file_path)
  local start_dir = vim.fn.fnamemodify(file_path, ":p:h")
  local dir = start_dir

  while dir ~= "" do
    local package_path = dir .. "/package.json"
    if vim.fn.filereadable(package_path) == 1 and package_has_marp_config(package_path) then
      return package_path, dir
    end

    for _, place in ipairs(config_places) do
      local config_path = dir .. "/" .. place
      if vim.fn.filereadable(config_path) == 1 then
        return config_path, dir
      end
    end

    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then
      break
    end
    dir = parent
  end

  return nil, start_dir
end

function M.argv(value)
  if type(value) == "table" then
    return vim.deepcopy(value)
  end

  if type(value) == "string" and value ~= "" then
    return vim.split(vim.trim(value), "%s+", { trimempty = true })
  end

  return {}
end

M.command_argv = M.argv

function M.resolve_command(command)
  local configured = M.argv(command)
  if #configured > 0 then
    return configured
  end

  local marp_path = vim.fn.exepath("marp")
  if marp_path ~= "" then
    return { marp_path }
  end

  return { "npx", "@marp-team/marp-cli@latest" }
end

function M.build_argv(command, args)
  local argv = M.argv(command)
  for _, arg in ipairs(args or {}) do
    table.insert(argv, tostring(arg))
  end
  return argv
end

function M.process_env(config)
  if config.node_options and config.node_options ~= "" then
    return { NODE_OPTIONS = config.node_options }
  end
  return nil
end

local function add_value(args, flag, value)
  if value ~= nil and value ~= "" then
    table.insert(args, flag)
    table.insert(args, value)
  end
end

local function add_boolean(args, flag, value)
  if value ~= nil then
    table.insert(args, flag .. "=" .. tostring(value))
  end
end

function M.common_args(config)
  local args = {}

  -- Marp CLI enables its hidden stdin input by default. Neovim jobs expose a
  -- non-TTY stdin pipe, so the CLI otherwise waits for input even when a file
  -- path was supplied (nwiizo/marp.nvim#2 and nwiizo/marp.nvim#3).
  if config.no_stdin ~= false then
    table.insert(args, "--no-stdin")
  end

  if config.config_file == false then
    table.insert(args, "--no-config-file")
  else
    add_value(args, "--config-file", config.config_file)
  end

  for _, path in ipairs(config.theme_set or {}) do
    add_value(args, "--theme-set", path)
  end

  if type(config.browser_kind) == "table" then
    add_value(args, "--browser", table.concat(config.browser_kind, ","))
  else
    add_value(args, "--browser", config.browser_kind)
  end
  add_value(args, "--browser-path", config.browser_path)
  add_value(args, "--browser-protocol", config.browser_protocol)
  add_value(args, "--browser-timeout", config.browser_timeout)

  add_value(args, "--template", config.template)
  add_boolean(args, "--bespoke.osc", config.bespoke_osc)
  add_boolean(args, "--bespoke.progress", config.bespoke_progress)
  add_boolean(args, "--bespoke.transition", config.bespoke_transition)

  return args
end

function M.export_args(config, format)
  local args = {}

  if format == "pdf" then
    if config.pdf_notes then
      table.insert(args, "--pdf-notes")
    end
    if config.pdf_outlines then
      table.insert(args, "--pdf-outlines")
      add_boolean(args, "--pdf-outlines.pages", config.pdf_outlines_pages)
      add_boolean(args, "--pdf-outlines.headings", config.pdf_outlines_headings)
    end
  elseif format == "pptx" and config.pptx_editable then
    table.insert(args, "--pptx-editable")
  end

  if format == "png" or format == "jpeg" or format == "thumbnail_png" or format == "thumbnail_jpeg" then
    if config.image_scale ~= 1 then
      add_value(args, "--image-scale", config.image_scale)
    end
  end

  if (format == "jpeg" or format == "thumbnail_jpeg") and config.jpeg_quality ~= 85 then
    add_value(args, "--jpeg-quality", config.jpeg_quality)
  end

  return args
end

return M
