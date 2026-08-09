local cli = require("marp.cli")

local M = {}

-- Store active Marp processes
M.active_processes = {}

-- Store additional metadata
M.metadata = {
  html_files = {}, -- Store generated HTML file paths
  last_export = {}, -- Store last export info
  process_retries = {}, -- Track retry attempts
  process_generations = {}, -- Cancel stale automatic restarts
  stopping_processes = {}, -- Retain handles until exit callbacks run
  browser_opened = {}, -- Track if browser was opened for buffer
}

-- Configuration
M.config = {
  marp_command = "marp",
  browser = nil, -- auto-detect
  themes = {
    default = "default",
    gaia = "gaia",
    uncover = "uncover",
  },
  export_formats = {
    html = "--html",
    pdf = "--pdf",
    pptx = "--pptx",
    png = "--images png",
    jpeg = "--images jpeg",
    notes = "--notes",
  },
  -- New config options for tips
  auto_copy_path = true,
  show_file_size = true,
  suggest_gitignore = true,
  debug = false, -- Enable debug logging
  server_mode = false, -- Use watch mode (-w) by default
  html_option = true, -- Use --html option in watch mode by default
  allow_local_files = false, -- Opt in to local asset access for trusted decks
  no_stdin = true, -- Prevent Marp CLI from waiting on Neovim's stdin pipe
  config_file = nil, -- Explicit config path (false disables config discovery)
  node_options = "", -- Set to "--experimental-require-module" if using custom node path with Node.js v25+
  -- Browser conversion options
  browser_kind = nil, -- "auto", "chrome", "edge", "firefox", or a preference list
  browser_path = nil, -- Path to a browser executable
  browser_protocol = nil, -- "cdp" or "webdriver-bidi"
  browser_timeout = nil, -- Timeout for browser operations in seconds
  -- HTML template options
  template = nil, -- "bare" or "bespoke"
  bespoke_osc = nil,
  bespoke_progress = nil,
  bespoke_transition = nil,
  -- PDF options
  pdf_notes = false, -- Add presenter notes to PDF as annotations
  pdf_outlines = false, -- Add outlines (bookmarks) to PDF
  pdf_outlines_pages = nil, -- Include slide pages in PDF outlines
  pdf_outlines_headings = nil, -- Include Markdown headings in PDF outlines
  -- PPTX options
  pptx_editable = false, -- Generate editable PPTX (experimental)
  -- Image options
  image_scale = 1, -- Scale factor for rendered images (2 for retina)
  jpeg_quality = 85, -- JPEG image quality (1-100)
  -- Theme options
  theme_set = {}, -- Additional theme CSS file paths
}

local function validate_string_list(name, value)
  if type(value) ~= "table" then
    return
  end
  for index, item in ipairs(value) do
    if type(item) ~= "string" or item == "" then
      error(string.format("%s[%d] must be a non-empty string", name, index), 3)
    end
  end
end

local function validate_config(opts)
  if opts == nil then
    return
  end

  for _, key in ipairs({ "marp_command", "browser", "browser_kind" }) do
    local value = opts[key]
    if value ~= nil and type(value) ~= "string" and type(value) ~= "table" then
      error("opts." .. key .. " must be a string or a list", 3)
    end
    validate_string_list("opts." .. key, value)
  end
  if opts.theme_set ~= nil and type(opts.theme_set) ~= "table" then
    error("opts.theme_set must be a list", 3)
  end
  validate_string_list("opts.theme_set", opts.theme_set)

  if opts.config_file ~= nil and opts.config_file ~= false and type(opts.config_file) ~= "string" then
    error("opts.config_file must be a string, false, or nil", 3)
  end
  if opts.image_scale ~= nil and (type(opts.image_scale) ~= "number" or opts.image_scale <= 0) then
    error("opts.image_scale must be a positive number", 3)
  end
  if
    opts.jpeg_quality ~= nil
    and (type(opts.jpeg_quality) ~= "number" or opts.jpeg_quality < 1 or opts.jpeg_quality > 100)
  then
    error("opts.jpeg_quality must be a number from 1 to 100", 3)
  end
  if opts.browser_timeout ~= nil and (type(opts.browser_timeout) ~= "number" or opts.browser_timeout < 0) then
    error("opts.browser_timeout must be a non-negative number", 3)
  end
end

-- Setup function
function M.setup(opts)
  if opts ~= nil and type(opts) ~= "table" then
    error("opts must be a table or nil", 2)
  end
  validate_config(opts)
  opts = opts or {}
  local merged = vim.tbl_deep_extend("force", M.config, opts)
  for _, key in ipairs({ "marp_command", "browser", "browser_kind", "theme_set" }) do
    if type(opts[key]) == "table" then
      merged[key] = vim.deepcopy(opts[key])
    end
  end
  M.config = merged
end

-- Helper function to clean ANSI escape sequences
local function clean_ansi(str)
  -- Remove ANSI escape sequences (colors, formatting, etc.)
  return str:gsub("\27%[[%d;]*m", ""):gsub("\27%[[%d;]*[A-Za-z]", "")
end

local function uri_encode_segment(str)
  return (str:gsub("[^%w%-._~]", function(char)
    return string.format("%%%02X", string.byte(char))
  end))
end

local function get_marp_config(file_path)
  if type(M.config.config_file) == "string" and M.config.config_file ~= "" then
    local config_path = vim.fn.fnamemodify(M.config.config_file, ":p")
    return config_path, vim.fn.fnamemodify(config_path, ":h")
  end

  return cli.find_config(file_path)
end

local function append_args(target, source)
  for _, value in ipairs(source or {}) do
    table.insert(target, value)
  end
end

local function common_args()
  local config = M.config
  if type(config.config_file) == "string" and config.config_file ~= "" then
    config = vim.deepcopy(config)
    config.config_file = vim.fn.fnamemodify(config.config_file, ":p")
  end
  return cli.common_args(config)
end

local function append_shared_args(args)
  if M.config.allow_local_files then
    table.insert(args, "--allow-local-files")
  end
  append_args(args, common_args())
end

local function file_args(file, args)
  args = vim.deepcopy(args or {})
  append_shared_args(args)
  table.insert(args, file)
  return args
end

-- Get Marp executable argv. A list is recommended when the command has args.
local function get_marp_cmd()
  return cli.resolve_command(M.config.marp_command)
end

local function build_marp_argv(args)
  return cli.build_argv(get_marp_cmd(), args)
end

local function system_options(opts)
  return vim.tbl_extend("force", {
    text = true,
    env = cli.process_env(M.config),
  }, opts or {})
end

local function start_marp(args, opts, on_exit)
  local ok, process = pcall(vim.system, build_marp_argv(args), system_options(opts), on_exit)
  if not ok then
    vim.notify("[Marp] Failed to start: " .. tostring(process), vim.log.levels.ERROR)
    return nil
  end
  return process
end

local function stream_lines(on_line)
  local pending = ""

  return function(err, data)
    if err then
      vim.schedule(function()
        vim.notify("[Marp] Process stream error: " .. err, vim.log.levels.ERROR)
      end)
      return
    end

    if data then
      pending = pending .. data
    end

    while true do
      local newline = pending:find("\n", 1, true)
      if not newline then
        break
      end

      local line = pending:sub(1, newline - 1):gsub("\r$", "")
      pending = pending:sub(newline + 1)
      if line ~= "" then
        vim.schedule(function()
          on_line(line)
        end)
      end
    end

    if data == nil and pending ~= "" then
      local line = pending
      pending = ""
      vim.schedule(function()
        on_line(line)
      end)
    end
  end
end

local function start_one_shot(args, cwd, label, on_success)
  return start_marp(
    args,
    { cwd = cwd },
    vim.schedule_wrap(function(result)
      if M.config.debug then
        if result.stdout and result.stdout ~= "" then
          vim.notify("[" .. label .. " stdout] " .. vim.trim(clean_ansi(result.stdout)), vim.log.levels.DEBUG)
        end
        if result.stderr and result.stderr ~= "" then
          vim.notify("[" .. label .. " stderr] " .. vim.trim(clean_ansi(result.stderr)), vim.log.levels.DEBUG)
        end
      end

      if result.code == 0 then
        on_success(result)
      else
        local detail = result.stderr and vim.trim(clean_ansi(result.stderr)) or ""
        local message = label .. " failed (exit code " .. result.code .. ")"
        if detail ~= "" then
          message = message .. ": " .. detail
        end
        vim.notify(message, vim.log.levels.ERROR)
      end
    end)
  )
end

local function next_process_generation(bufnr)
  local generation = (M.metadata.process_generations[bufnr] or 0) + 1
  M.metadata.process_generations[bufnr] = generation
  return generation
end

local function request_process_stop(bufnr, silent)
  local process = M.active_processes[bufnr]

  -- Invalidate both a running process and any deferred automatic restart.
  next_process_generation(bufnr)
  M.metadata.process_retries[bufnr] = 999
  M.metadata.browser_opened[bufnr] = nil

  if not process then
    return false
  end

  M.metadata.stopping_processes[bufnr] = {
    process = process,
    silent = silent,
  }

  local success = pcall(process.kill, process, 15)
  if not success then
    M.metadata.stopping_processes[bufnr] = nil
    vim.notify("Failed to stop Marp process", vim.log.levels.WARN)
    return true
  end

  -- Retain the handle until the exit callback runs, and escalate if SIGTERM is
  -- ignored. This also keeps replacement watches from overlapping.
  vim.defer_fn(function()
    if M.active_processes[bufnr] == process then
      pcall(process.kill, process, 9)
    end
  end, 1000)

  return true
end

local function wait_for_process_exit(bufnr)
  if vim.wait(1100, function()
    return M.active_processes[bufnr] == nil
  end, 20) then
    return true
  end

  local process = M.active_processes[bufnr]
  if process then
    pcall(process.kill, process, 9)
  end

  return vim.wait(1000, function()
    return M.active_processes[bufnr] == nil
  end, 20)
end

local function prepare_watch_output(bufnr, html_file, server_mode)
  if server_mode then
    M.metadata.html_files[bufnr] = nil
    return
  end

  M.metadata.html_files[bufnr] = html_file
  vim.notify("HTML file: " .. html_file, vim.log.levels.INFO)

  if M.config.auto_copy_path then
    vim.fn.setreg("+", html_file)
    vim.notify("✓ Path copied to clipboard", vim.log.levels.INFO)
  end

  if M.config.suggest_gitignore then
    M.check_gitignore(html_file)
  end
end

local function watch_output_handler(bufnr, file, html_file, server_mode, generation)
  local last_update_time = 0

  return function(line)
    if M.metadata.process_generations[bufnr] ~= generation then
      return
    end

    local clean_line = clean_ansi(line)
    vim.notify("[Marp] " .. clean_line, vim.log.levels.INFO)

    if server_mode and not M.metadata.browser_opened[bufnr] then
      local server_url = clean_line:match("(https?://localhost:%d+/?)")
      if server_url then
        if not server_url:match("/$") then
          server_url = server_url .. "/"
        end
        M.open_browser(server_url .. uri_encode_segment(vim.fn.fnamemodify(file, ":t")))
        M.metadata.browser_opened[bufnr] = true
      end
    end

    if clean_line:match("=>") or clean_line:match("has been written") then
      if not server_mode and not M.metadata.browser_opened[bufnr] then
        M.open_browser(vim.uri_from_fname(html_file))
        M.metadata.browser_opened[bufnr] = true
      end

      local current_time = vim.uv.now()
      if current_time - last_update_time > 1000 then
        vim.notify("🔄 HTML updated", vim.log.levels.INFO)
        last_update_time = current_time
      end
    end
  end
end

local function register_buffer_cleanup(bufnr)
  local augroup = vim.api.nvim_create_augroup("marp.nvim", { clear = false })
  vim.api.nvim_clear_autocmds({
    group = augroup,
    event = { "BufDelete", "BufWipeout" },
    buffer = bufnr,
  })
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = augroup,
    buffer = bufnr,
    once = true,
    desc = "Stop Marp when its source buffer closes",
    callback = function()
      M.stop(bufnr, true)
    end,
  })
end

local function start_watch_process(bufnr, file, html_file, args, project_root, server_mode, generation)
  local handle_output = watch_output_handler(bufnr, file, html_file, server_mode, generation)
  local process
  process = start_marp(
    args,
    {
      cwd = project_root,
      stdout = stream_lines(handle_output),
      stderr = stream_lines(handle_output),
    },
    vim.schedule_wrap(function(result)
      if M.active_processes[bufnr] == process then
        M.active_processes[bufnr] = nil
      end

      local stopping = M.metadata.stopping_processes[bufnr]
      if stopping and stopping.process == process then
        M.metadata.stopping_processes[bufnr] = nil
        if not stopping.silent then
          vim.notify("Marp process stopped", vim.log.levels.INFO)
        end
        return
      end

      if M.metadata.process_generations[bufnr] ~= generation then
        return
      end

      if result.code ~= 0 and result.signal ~= 15 then
        vim.notify("Marp process exited with code: " .. result.code, vim.log.levels.WARN)
        local retries = M.metadata.process_retries[bufnr] or 0
        if retries < 3 and vim.api.nvim_buf_is_valid(bufnr) then
          retries = retries + 1
          M.metadata.process_retries[bufnr] = retries
          vim.notify("Restarting Marp process (attempt " .. retries .. "/3)...", vim.log.levels.INFO)
          vim.defer_fn(function()
            if
              M.metadata.process_generations[bufnr] == generation
              and vim.api.nvim_buf_is_valid(bufnr)
              and not M.active_processes[bufnr]
            then
              vim.api.nvim_buf_call(bufnr, function()
                M.watch(generation)
              end)
            end
          end, 2000)
        else
          vim.notify("Marp process retry limit reached", vim.log.levels.ERROR)
        end
      else
        vim.notify("Marp process stopped", vim.log.levels.INFO)
      end
    end)
  )

  if not process then
    vim.notify("Failed to start Marp process", vim.log.levels.ERROR)
    return
  end

  M.active_processes[bufnr] = process
  vim.notify("Marp process started (PID: " .. process.pid .. ")", vim.log.levels.INFO)
  register_buffer_cleanup(bufnr)
end

-- Watch current file with Marp. retry_generation is private lifecycle state.
function M.watch(retry_generation)
  local bufnr = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(bufnr)

  if file == "" then
    vim.notify("No file in current buffer", vim.log.levels.ERROR)
    return
  end

  if not file:match("%.md$") then
    vim.notify("Not a markdown file", vim.log.levels.ERROR)
    return
  end

  local generation
  if retry_generation ~= nil then
    if M.metadata.process_generations[bufnr] ~= retry_generation then
      return
    end
    generation = retry_generation
  else
    if M.active_processes[bufnr] then
      vim.notify("Stopping existing Marp process...", vim.log.levels.INFO)
      request_process_stop(bufnr, true)
      if not wait_for_process_exit(bufnr) then
        vim.notify("Could not stop the existing Marp process", vim.log.levels.ERROR)
        return
      end
    end
    generation = next_process_generation(bufnr)
    M.metadata.process_retries[bufnr] = 0
    M.metadata.browser_opened[bufnr] = false
  end

  local _, project_root = get_marp_config(file)
  local html_file = file:gsub("%.md$", ".html")
  local server_mode = M.config.server_mode
  local action_args = {}
  if server_mode then
    table.insert(action_args, "--server")
    table.insert(action_args, vim.fn.fnamemodify(file, ":h"))
    append_shared_args(action_args)
  else
    table.insert(action_args, "--watch")
    if M.config.html_option then
      table.insert(action_args, "--html")
    end
    table.insert(action_args, "--output")
    table.insert(action_args, html_file)
    action_args = file_args(file, action_args)
  end
  prepare_watch_output(bufnr, html_file, server_mode)
  vim.notify("Starting Marp: " .. table.concat(build_marp_argv(action_args), " "), vim.log.levels.INFO)

  start_watch_process(bufnr, file, html_file, action_args, project_root, server_mode, generation)
end

-- Stop Marp process for buffer
function M.stop(bufnr, silent)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not request_process_stop(bufnr, silent) and not silent then
    vim.notify("No active Marp process for this buffer", vim.log.levels.INFO)
  end
end

-- Stop all Marp processes
function M.stop_all(silent)
  local buffers = vim.tbl_keys(M.active_processes)
  if #buffers == 0 then
    if not silent then
      vim.notify("No active Marp processes", vim.log.levels.INFO)
    end
    return
  end
  for _, bufnr in ipairs(buffers) do
    request_process_stop(bufnr, true)
  end
  if not silent then
    vim.notify("Stopping all Marp processes", vim.log.levels.INFO)
  end
end

local function image_output_spec(output_base, format)
  local directory = vim.fn.fnamemodify(output_base, ":h")
  local basename = vim.fn.fnamemodify(output_base, ":t")
  local lower = basename:lower()
  if lower:match("%.png$") then
    basename = basename:sub(1, -5)
  elseif lower:match("%.jpg$") or lower:match("%.jpeg$") then
    basename = basename:sub(1, lower:match("%.jpeg$") and -6 or -5)
  end

  local extension = format == "jpeg" and "jpg" or "png"
  local pattern = "^" .. basename:gsub("([^%w])", "%%%1") .. "%.%d+%." .. extension .. "$"
  return directory, pattern
end

local function scan_image_outputs(output_base, format)
  local directory, pattern = image_output_spec(output_base, format)
  local paths = {}
  local ok, iterator = pcall(vim.fs.dir, directory)
  if ok and iterator then
    for name, entry_type in iterator do
      if entry_type == "file" and name:match(pattern) then
        table.insert(paths, directory .. "/" .. name)
      end
    end
  end
  table.sort(paths)
  return paths
end

local function file_fingerprint(path)
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return nil
  end
  return table.concat({ stat.size, stat.mtime.sec, stat.mtime.nsec }, ":")
end

local function image_output_snapshot(output_base, format)
  local snapshot = {}
  for _, path in ipairs(scan_image_outputs(output_base, format)) do
    snapshot[path] = file_fingerprint(path)
  end
  return snapshot
end

local function current_image_outputs(result, output_base, format, project_root, previous)
  local directory, pattern = image_output_spec(output_base, format)
  directory = vim.fn.fnamemodify(directory, ":p")
  local paths = {}
  local seen = {}

  for line in (clean_ansi(result.stdout or "") .. "\n"):gmatch("(.-)\r?\n") do
    local path = line:match("=>%s+(.+)%s*$")
    if path then
      if not path:match("^/") and not path:match("^%a:[/\\]") then
        path = project_root .. "/" .. path
      end
      path = vim.fn.fnamemodify(path, ":p")
      if
        vim.fn.fnamemodify(path, ":h") == directory
        and vim.fn.fnamemodify(path, ":t"):match(pattern)
        and vim.fn.filereadable(path) == 1
        and not seen[path]
      then
        table.insert(paths, path)
        seen[path] = true
      end
    end
  end

  -- Fall back to filesystem changes for wrappers that suppress Marp's stdout.
  if #paths == 0 then
    for _, path in ipairs(scan_image_outputs(output_base, format)) do
      if previous[path] ~= file_fingerprint(path) then
        table.insert(paths, path)
      end
    end
  end

  table.sort(paths)
  return paths
end

local function record_export(format, paths)
  M.metadata.last_export = {
    format = format,
    file = paths[1],
    files = paths,
    time = os.date("%Y-%m-%d %H:%M:%S"),
  }

  if #paths == 1 then
    vim.notify("✅ Exported: " .. paths[1], vim.log.levels.INFO)
  else
    vim.notify("✅ Exported " .. #paths .. " files:\n" .. table.concat(paths, "\n"), vim.log.levels.INFO)
  end

  if M.config.show_file_size then
    local total_size = 0
    for _, path in ipairs(paths) do
      if vim.fn.filereadable(path) == 1 then
        total_size = total_size + vim.fn.getfsize(path)
      end
    end
    if total_size > 0 then
      vim.notify("📊 File size: " .. M.format_file_size(total_size), vim.log.levels.INFO)
    end
  end

  if M.config.auto_copy_path then
    vim.fn.setreg("+", table.concat(paths, "\n"))
    vim.notify("✓ Path copied to clipboard", vim.log.levels.INFO)
  end
end

-- Export current file
function M.export(format, output)
  local file = vim.api.nvim_buf_get_name(0)

  if file == "" or not file:match("%.md$") then
    vim.notify("Not a markdown file", vim.log.levels.ERROR)
    return
  end

  if format == nil or format == "" then
    format = "html"
  end
  local export_flag = M.config.export_formats[format]

  if not export_flag then
    vim.notify("Unknown export format: " .. format, vim.log.levels.ERROR)
    return
  end

  local _, project_root = get_marp_config(file)
  local args = cli.argv(export_flag)
  append_args(args, cli.export_args(M.config, format))

  local output_file = file:gsub("%.md$", "")
  local ext_map = {
    html = ".html",
    pdf = ".pdf",
    pptx = ".pptx",
    notes = ".txt",
  }
  local output_path
  local image_output_base
  local previous_image_outputs
  if output and output ~= "" then
    if output:match("^/") or output:match("^%a:[/\\]") then
      output_path = output
    else
      output_path = project_root .. "/" .. output
    end
    output_path = vim.fn.fnamemodify(output_path, ":p")
    table.insert(args, "--output")
    table.insert(args, output_path)
    if format == "png" or format == "jpeg" then
      image_output_base = output_path
    end
  elseif format == "png" or format == "jpeg" then
    image_output_base = output_file
    local extension = format == "jpeg" and ".001.jpg" or ".001.png"
    output_path = output_file .. extension
  else
    output_path = output_file .. (ext_map[format] or "")
  end
  if image_output_base then
    previous_image_outputs = image_output_snapshot(image_output_base, format)
  end
  args = file_args(file, args)

  vim.notify("📤 Exporting to " .. format .. "...", vim.log.levels.INFO)

  start_one_shot(args, project_root, "Export", function(result)
    local paths = { output_path }
    if image_output_base then
      paths = current_image_outputs(result, image_output_base, format, project_root, previous_image_outputs)
      if #paths == 0 then
        vim.notify("Export succeeded, but no numbered image outputs were found", vim.log.levels.WARN)
        paths = { output_path }
      end
    end
    record_export(format, paths)
  end)
end

-- Preview current file (one-time)
function M.preview()
  local bufnr = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(bufnr)

  if file == "" or not file:match("%.md$") then
    vim.notify("Not a markdown file", vim.log.levels.ERROR)
    return
  end

  local _, project_root = get_marp_config(file)
  local html_file = file:gsub("%.md$", ".html")
  local args = { "--html" }
  table.insert(args, "--output")
  table.insert(args, html_file)
  args = file_args(file, args)

  vim.notify("Generating preview...", vim.log.levels.INFO)
  start_one_shot(args, project_root, "Preview", function()
    M.metadata.html_files[bufnr] = html_file
    M.open_browser(vim.uri_from_fname(html_file))
    vim.notify("Preview opened: " .. html_file, vim.log.levels.INFO)
  end)
end

-- Generate thumbnail from first slide
function M.thumbnail(format)
  local file = vim.api.nvim_buf_get_name(0)

  if file == "" or not file:match("%.md$") then
    vim.notify("Not a markdown file", vim.log.levels.ERROR)
    return
  end

  if format == nil or format == "" then
    format = "png"
  end
  if format ~= "png" and format ~= "jpeg" then
    vim.notify("Thumbnail format must be png or jpeg", vim.log.levels.ERROR)
    return
  end

  local _, project_root = get_marp_config(file)
  local args = { "--image", format }
  append_args(args, cli.export_args(M.config, "thumbnail_" .. format))
  args = file_args(file, args)

  local ext = format == "jpeg" and ".jpg" or ".png"
  local output_path = file:gsub("%.md$", ext)

  vim.notify("Generating thumbnail...", vim.log.levels.INFO)

  start_one_shot(args, project_root, "Thumbnail", function()
    record_export("thumbnail_" .. format, { output_path })
  end)
end

-- Set theme
function M.set_theme(theme)
  if not M.config.themes[theme] then
    vim.notify("Unknown theme: " .. theme, vim.log.levels.ERROR)
    return
  end

  -- Insert or update theme directive at the beginning of the file
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local theme_line = "theme: " .. theme

  -- Check if marp directive exists
  local has_marp = false
  local theme_line_idx = nil

  for i, line in ipairs(lines) do
    if i == 1 and line == "---" then
      has_marp = true
    elseif line:match("^theme:") then
      theme_line_idx = i
      break
    elseif line == "---" and i > 1 then
      break
    end
  end

  if has_marp and theme_line_idx then
    -- Update existing theme
    lines[theme_line_idx] = theme_line
  elseif has_marp then
    -- Add theme after opening ---
    table.insert(lines, 2, theme_line)
  else
    -- Add marp frontmatter
    table.insert(lines, 1, "---")
    table.insert(lines, 2, "marp: true")
    table.insert(lines, 3, theme_line)
    table.insert(lines, 4, "---")
  end

  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.notify("Theme set to: " .. theme, vim.log.levels.INFO)
end

-- Insert Marp snippet
function M.insert_snippet(snippet_name)
  local snippets = {
    title = {
      "<!-- _class: lead -->",
      "",
      "# Title",
      "",
      "## Subtitle",
      "",
      "Author Name",
      "Date",
      "",
      "---",
    },
    columns = {
      "<!-- _class: cols -->",
      "",
      ":::: cols",
      "",
      "::: left",
      "",
      "Left column content",
      "",
      ":::",
      "",
      "::: right",
      "",
      "Right column content",
      "",
      ":::",
      "",
      "::::",
    },
    image = {
      "![alt text](image.png)",
    },
    bg_image = {
      "<!-- _backgroundImage: url('image.png') -->",
    },
    center = {
      "<!-- _class: center -->",
      "",
      "Centered content",
    },
    speaker_notes = {
      "<!--",
      "Speaker notes here",
      "-->",
    },
  }

  local snippet = snippets[snippet_name]
  if not snippet then
    vim.notify("Unknown snippet: " .. snippet_name, vim.log.levels.ERROR)
    return
  end

  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  vim.api.nvim_buf_set_lines(0, row, row, false, snippet)
  vim.notify("Inserted " .. snippet_name .. " snippet", vim.log.levels.INFO)
end

-- Open browser
function M.open_browser(url)
  local cmd
  if type(M.config.browser) == "table" then
    cmd = vim.deepcopy(M.config.browser)
    table.insert(cmd, url)
  elseif M.config.browser then
    cmd = { M.config.browser, url }
  end

  -- An explicit opener always takes precedence over Neovim's default.
  if cmd then
    local ok, result = pcall(vim.system, cmd, { detach = true })
    if not ok then
      vim.notify("[Marp] Failed to start browser: " .. tostring(result), vim.log.levels.ERROR)
    end
    return
  end

  if vim.ui and vim.ui.open then
    local ok, process, error_message = pcall(vim.ui.open, url)
    if ok and process then
      return
    end
    local detail = ok and error_message or process
    vim.notify("[Marp] vim.ui.open failed: " .. tostring(detail) .. ", falling back", vim.log.levels.WARN)
  end

  -- Fallback for environments without a working default opener.
  if vim.fn.has("mac") == 1 then
    cmd = { "open", url }
  elseif vim.fn.has("unix") == 1 then
    cmd = { "xdg-open", url }
  elseif vim.fn.has("win32") == 1 then
    cmd = { "cmd", "/c", "start", "", url }
  else
    vim.notify("[Marp] Could not detect browser", vim.log.levels.ERROR)
    return
  end

  local ok, result = pcall(vim.system, cmd, { detach = true })
  if not ok then
    vim.notify("[Marp] Failed to start browser: " .. tostring(result), vim.log.levels.ERROR)
  end
end

-- List active processes
function M.list_active()
  if vim.tbl_isempty(M.active_processes) then
    vim.notify("No active Marp processes", vim.log.levels.INFO)
    return
  end

  local active = {}
  for bufnr, _ in pairs(M.active_processes) do
    local name = vim.api.nvim_buf_get_name(bufnr)
    table.insert(active, vim.fn.fnamemodify(name, ":t"))
  end

  vim.notify("Active Marp processes:\n" .. table.concat(active, "\n"), vim.log.levels.INFO)
end

-- Format file size
function M.format_file_size(size)
  if size < 1024 then
    return string.format("%d B", size)
  elseif size < 1024 * 1024 then
    return string.format("%.1f KB", size / 1024)
  elseif size < 1024 * 1024 * 1024 then
    return string.format("%.1f MB", size / (1024 * 1024))
  else
    return string.format("%.1f GB", size / (1024 * 1024 * 1024))
  end
end

-- Check gitignore
function M.check_gitignore(html_file)
  local gitignore = vim.fn.findfile(".gitignore", ".;")
  if gitignore ~= "" then
    local content = vim.fn.readfile(gitignore)
    local has_html = false
    for _, line in ipairs(content) do
      if line:match("%.html$") or line:match("%*%.html") then
        has_html = true
        break
      end
    end

    if not has_html then
      vim.notify("💡 Tip: Consider adding '*.html' to .gitignore", vim.log.levels.WARN)
    end
  end
end

-- Show current Marp info
function M.info()
  local bufnr = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(bufnr)

  if file == "" or not file:match("%.md$") then
    vim.notify("Not a markdown file", vim.log.levels.ERROR)
    return
  end

  local info = {}
  table.insert(info, "📄 Marp Info")
  table.insert(info, "============")
  table.insert(info, "File: " .. vim.fn.fnamemodify(file, ":t"))

  -- Check if server is active
  if M.active_processes[bufnr] then
    table.insert(info, "Server: 🟢 Active")
  else
    table.insert(info, "Server: 🔴 Inactive")
  end

  -- Get current theme
  local lines = vim.api.nvim_buf_get_lines(0, 0, 20, false)
  local current_theme = "default"
  for _, line in ipairs(lines) do
    local theme = line:match("^theme:%s*(.+)")
    if theme then
      current_theme = vim.trim(theme)
      break
    end
  end
  table.insert(info, "Theme: " .. current_theme)

  -- Count slides
  local slide_count = 1
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    if line == "---" then
      slide_count = slide_count + 1
    end
  end
  table.insert(info, "Slides: " .. slide_count)

  -- File size
  if vim.fn.filereadable(file) == 1 then
    local size = vim.fn.getfsize(file)
    table.insert(info, "Size: " .. M.format_file_size(size))
  end

  -- Last export info
  if M.metadata.last_export.file then
    table.insert(info, "")
    table.insert(info, "Last Export:")
    table.insert(info, "  Format: " .. M.metadata.last_export.format)
    if M.metadata.last_export.files and #M.metadata.last_export.files > 1 then
      table.insert(info, "  Files: " .. #M.metadata.last_export.files)
    else
      table.insert(info, "  File: " .. M.metadata.last_export.file)
    end
    table.insert(info, "  Time: " .. M.metadata.last_export.time)
  end

  -- HTML file path
  if M.metadata.html_files[bufnr] then
    table.insert(info, "")
    table.insert(info, "HTML: " .. M.metadata.html_files[bufnr])
  end

  vim.notify(table.concat(info, "\n"), vim.log.levels.INFO)
end

-- Copy current HTML path
function M.copy_html_path()
  local bufnr = vim.api.nvim_get_current_buf()
  local html_file = M.metadata.html_files[bufnr]

  if html_file then
    vim.fn.setreg("+", html_file)
    vim.notify("✓ HTML path copied: " .. html_file, vim.log.levels.INFO)
  else
    local file = vim.api.nvim_buf_get_name(bufnr)
    if file ~= "" and file:match("%.md$") then
      html_file = file:gsub("%.md$", ".html")
      vim.fn.setreg("+", html_file)
      vim.notify("✓ HTML path copied: " .. html_file, vim.log.levels.INFO)
    else
      vim.notify("No HTML file path available", vim.log.levels.WARN)
    end
  end
end

-- Open the Marp CLI configuration detected for the current file
function M.open_config()
  local file = vim.api.nvim_buf_get_name(0)

  if file == "" then
    vim.notify("No file in current buffer", vim.log.levels.ERROR)
    return
  end

  if M.config.config_file == false then
    vim.notify("Marp config discovery is disabled", vim.log.levels.INFO)
    return
  end

  local config_path = get_marp_config(file)
  if not config_path or vim.fn.filereadable(config_path) ~= 1 then
    vim.notify("No Marp config found", vim.log.levels.INFO)
    return
  end

  vim.cmd("edit " .. vim.fn.fnameescape(config_path))
end

-- Debug function to test Marp command
function M.debug()
  local bufnr = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(bufnr)

  if file == "" or not file:match("%.md$") then
    vim.notify("Not a markdown file", vim.log.levels.ERROR)
    return
  end

  local marp_cmd = get_marp_cmd()
  local config_path, project_root = get_marp_config(file)
  local test_args = { "--version" }
  append_args(test_args, common_args())

  vim.notify("=== Marp Debug Info ===", vim.log.levels.INFO)
  vim.notify("Testing Marp command...", vim.log.levels.INFO)

  -- Show current state
  vim.notify("Buffer: " .. bufnr, vim.log.levels.INFO)
  vim.notify("File: " .. file, vim.log.levels.INFO)
  vim.notify("Project root: " .. project_root, vim.log.levels.INFO)
  local active_process = M.active_processes[bufnr]
  vim.notify("Active process: " .. (active_process and active_process.pid or "none"), vim.log.levels.INFO)

  -- Show detected config file
  vim.notify("Config file: " .. (config_path or "none"), vim.log.levels.INFO)

  -- Show metadata
  if M.metadata.process_retries[bufnr] then
    vim.notify("Process retries: " .. M.metadata.process_retries[bufnr], vim.log.levels.INFO)
  end
  if M.metadata.browser_opened[bufnr] then
    vim.notify("Browser opened: " .. tostring(M.metadata.browser_opened[bufnr]), vim.log.levels.INFO)
  end

  -- Show config
  vim.notify("Server mode: " .. tostring(M.config.server_mode), vim.log.levels.INFO)
  vim.notify("Debug mode: " .. tostring(M.config.debug), vim.log.levels.INFO)
  vim.notify("Allow local files: " .. tostring(M.config.allow_local_files), vim.log.levels.INFO)

  start_one_shot(test_args, project_root, "Debug", function(result)
    vim.notify("Marp version: " .. vim.trim(clean_ansi(result.stdout or "")), vim.log.levels.INFO)
    vim.notify("✅ Marp command is working!", vim.log.levels.INFO)
    vim.notify("Command: " .. table.concat(marp_cmd, " "), vim.log.levels.INFO)

    local browser_cmd = M.config.browser or (vim.fn.has("mac") == 1 and "open" or "xdg-open")
    if type(browser_cmd) == "table" then
      browser_cmd = table.concat(browser_cmd, " ")
    end
    vim.notify("Browser command: " .. browser_cmd, vim.log.levels.INFO)
  end)
end

return M
