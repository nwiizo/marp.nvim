local M = {}

-- Store active Marp processes
M.active_processes = {}

-- Store additional metadata
M.metadata = {
  html_files = {},  -- Store generated HTML file paths
  last_export = {}, -- Store last export info
  usage_stats = {}, -- Store usage statistics
}

-- Configuration
M.config = {
  marp_command = "/opt/homebrew/opt/node/bin/node /opt/homebrew/bin/marp",
  browser = nil, -- auto-detect
  themes = {
    default = "default",
    gaia = "gaia",
    uncover = "uncover"
  },
  export_formats = {
    html = "--html",
    pdf = "--pdf",
    pptx = "--pptx",
    png = "--images png",
    jpeg = "--images jpeg"
  },
  -- New config options for tips
  show_tips = true,
  auto_copy_path = true,
  show_file_size = true,
  suggest_gitignore = true,
  debug = true, -- Enable debug logging
  server_mode = false  -- Use watch mode (-w) by default
}

-- Setup function
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

-- Helper function to clean ANSI escape sequences
local function clean_ansi(str)
  -- Remove ANSI escape sequences (colors, formatting, etc.)
  return str:gsub("\27%[[%d;]*m", ""):gsub("\27%[[%d;]*[A-Za-z]", "")
end

-- Get Marp executable
local function get_marp_cmd()
  -- First check if custom command is set
  if M.config.marp_command and M.config.marp_command ~= "" then
    return M.config.marp_command
  end
  
  -- Check if marp is available locally
  local marp_check = vim.fn.system("which marp")
  if vim.v.shell_error == 0 and marp_check ~= "" then
    return vim.trim(marp_check)
  end
  
  -- Default to npx
  return "npx @marp-team/marp-cli@latest"
end

-- Watch current file with Marp
function M.watch()
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
  
  -- Stop existing process for this buffer
  if M.active_processes[bufnr] then
    vim.notify("Stopping existing Marp process...", vim.log.levels.INFO)
    M.stop(bufnr)
    -- Wait a bit for the process to stop
    vim.wait(500)
  end
  
  local marp_cmd = get_marp_cmd()
  
  -- Calculate HTML file path
  local html_file = file:gsub("%.md$", ".html")
  M.metadata.html_files[bufnr] = html_file
  
  -- Choose between server mode (-s) or watch mode (--watch) based on config
  local cmd
  if M.config.server_mode then
    cmd = string.format("%s -s '%s'", marp_cmd, file)
  else
    -- Use --watch without -o (output file is determined automatically)
    cmd = string.format("%s --watch '%s'", marp_cmd, file)
  end
  
  -- Show HTML file path
  vim.notify("HTML file: " .. html_file, vim.log.levels.INFO)
  
  -- Copy to clipboard if enabled
  if M.config.auto_copy_path then
    vim.fn.setreg("+", html_file)
    vim.notify("✓ Path copied to clipboard", vim.log.levels.INFO)
  end
  
  -- Check if HTML should be gitignored
  if M.config.suggest_gitignore then
    M.check_gitignore(html_file)
  end
  
  -- Debug output the command
  vim.notify("Starting Marp: " .. cmd, vim.log.levels.INFO)
  
  -- First generate HTML file if in watch mode
  if not M.config.server_mode then
    vim.notify("Generating initial HTML...", vim.log.levels.INFO)
    local init_cmd = string.format("%s '%s' -o '%s'", marp_cmd, file, html_file)
    vim.fn.system(init_cmd)
    
    if vim.fn.filereadable(html_file) == 1 then
      vim.notify("✅ Initial HTML generated", vim.log.levels.INFO)
      -- Open browser immediately
      M.open_browser("file://" .. html_file)
    end
  end
  
  -- Start Marp in a terminal
  local server_started = false
  local preview_opened = false
  local html_generated = not M.config.server_mode -- Already generated if in watch mode
  -- Use shell to execute the command properly
  local shell_cmd = {"/bin/sh", "-c", cmd}
  local job_id = vim.fn.jobstart(shell_cmd, {
    pty = true,  -- Use pseudo-terminal for proper output capture
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          vim.schedule(function()
            local clean_line = clean_ansi(line)
            
            -- Always show all output to see what's happening
            vim.notify("[Marp] " .. clean_line, vim.log.levels.INFO)
            
            -- Check for file conversion patterns
            if clean_line:match("=>") then
              vim.notify("🔄 HTML updated", vim.log.levels.INFO)
            end
          end)
        end
      end
    end,
    on_stderr = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          vim.schedule(function()
            local clean_line = clean_ansi(line)
            
            -- Always show all output to see what's happening
            vim.notify("[Marp] " .. clean_line, vim.log.levels.INFO)
            
            -- Check for file conversion patterns
            if clean_line:match("=>") then
              vim.notify("🔄 HTML updated", vim.log.levels.INFO)
            end
          end)
        end
      end
    end,
    on_exit = function()
      M.active_processes[bufnr] = nil
      vim.notify("Marp server stopped", vim.log.levels.INFO)
    end
  })
  
  if job_id > 0 then
    M.active_processes[bufnr] = job_id
    vim.notify("Marp process started (job ID: " .. job_id .. ")", vim.log.levels.INFO)
    
    -- Set up autocmd to stop process when buffer is deleted/wiped
    vim.api.nvim_create_autocmd({"BufDelete", "BufWipeout"}, {
      buffer = bufnr,
      once = true,
      callback = function()
        M.stop(bufnr)
      end
    })
    
  else
    vim.notify("Failed to start Marp server", vim.log.levels.ERROR)
  end
end

-- Stop Marp process for buffer
function M.stop(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local job_id = M.active_processes[bufnr]
  
  if job_id then
    -- Try to stop the job gracefully
    local success = pcall(function()
      vim.fn.jobstop(job_id)
    end)
    
    if success then
      vim.notify("Marp process stopped", vim.log.levels.INFO)
    else
      vim.notify("Failed to stop Marp process", vim.log.levels.WARN)
    end
    
    M.active_processes[bufnr] = nil
  else
    vim.notify("No active Marp process for this buffer", vim.log.levels.INFO)
  end
end

-- Stop all Marp processes
function M.stop_all()
  for bufnr, job_id in pairs(M.active_processes) do
    vim.fn.jobstop(job_id)
  end
  M.active_processes = {}
  vim.notify("All Marp servers stopped", vim.log.levels.INFO)
end

-- Export current file
function M.export(format)
  local file = vim.api.nvim_buf_get_name(0)
  
  if file == "" or not file:match("%.md$") then
    vim.notify("Not a markdown file", vim.log.levels.ERROR)
    return
  end
  
  format = format or "html"
  local export_flag = M.config.export_formats[format]
  
  if not export_flag then
    vim.notify("Unknown export format: " .. format, vim.log.levels.ERROR)
    return
  end
  
  local marp_cmd = get_marp_cmd()
  local output_file = file:gsub("%.md$", "")
  local cmd = string.format("%s %s '%s'", marp_cmd, export_flag, file)
  
  -- Determine output filename
  local ext_map = {
    html = ".html",
    pdf = ".pdf",
    pptx = ".pptx",
    png = ".001.png",
    jpeg = ".001.jpg"
  }
  local output_path = output_file .. (ext_map[format] or "")
  
  vim.notify("📤 Exporting to " .. format .. "...", vim.log.levels.INFO)
  
  local shell_cmd = {"/bin/sh", "-c", cmd}
  vim.fn.jobstart(shell_cmd, {
    stdout_buffered = false,
    stderr_buffered = false,
    detach = true,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          vim.schedule(function()
            local clean_line = clean_ansi(line)
            if M.config.debug then
              vim.notify("[Export stdout] " .. clean_line, vim.log.levels.DEBUG)
            end
          end)
        end
      end
    end,
    on_stderr = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          vim.schedule(function()
            local clean_line = clean_ansi(line)
            if M.config.debug then
              vim.notify("[Export stderr] " .. clean_line, vim.log.levels.DEBUG)
            end
          end)
        end
      end
    end,
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        -- Store export info
        M.metadata.last_export = {
          format = format,
          file = output_path,
          time = os.date("%Y-%m-%d %H:%M:%S")
        }
        
        vim.notify("✅ Exported: " .. output_path, vim.log.levels.INFO)
        
        -- Show file size if enabled
        if M.config.show_file_size and vim.fn.filereadable(output_path) == 1 then
          local size = vim.fn.getfsize(output_path)
          local size_str = M.format_file_size(size)
          vim.notify("📊 File size: " .. size_str, vim.log.levels.INFO)
        end
        
        -- Copy path to clipboard
        if M.config.auto_copy_path then
          vim.fn.setreg("+", output_path)
          vim.notify("✓ Path copied to clipboard", vim.log.levels.INFO)
        end
      else
        vim.notify("❌ Export failed", vim.log.levels.ERROR)
      end
    end
  })
end

-- Preview current file (one-time)
function M.preview()
  local file = vim.api.nvim_buf_get_name(0)
  
  if file == "" or not file:match("%.md$") then
    vim.notify("Not a markdown file", vim.log.levels.ERROR)
    return
  end
  
  local marp_cmd = get_marp_cmd()
  local cmd = string.format("%s -p '%s'", marp_cmd, file)
  
  local shell_cmd = {"/bin/sh", "-c", cmd}
  vim.fn.jobstart(shell_cmd, {
    stdout_buffered = false,
    stderr_buffered = false,
    detach = true,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          vim.schedule(function()
            local clean_line = clean_ansi(line)
            if M.config.debug then
              vim.notify("[Preview stdout] " .. clean_line, vim.log.levels.DEBUG)
            end
            
            if clean_line:match("http://localhost:%d+") then
              local url = clean_line:match("(http://localhost:%d+[^%s]*)")
              if url then
                M.open_browser(url)
              end
            end
          end)
        end
      end
    end,
    on_stderr = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          vim.schedule(function()
            local clean_line = clean_ansi(line)
            if M.config.debug then
              vim.notify("[Preview stderr] " .. clean_line, vim.log.levels.DEBUG)
            end
            
            if clean_line:match("http://localhost:%d+") then
              local url = clean_line:match("(http://localhost:%d+[^%s]*)")
              if url then
                M.open_browser(url)
              end
            end
          end)
        end
      end
    end
  })
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
      "---"
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
      "::::"
    },
    image = {
      "![alt text](image.png)"
    },
    bg_image = {
      "<!-- _backgroundImage: url('image.png') -->"
    },
    center = {
      "<!-- _class: center -->",
      "",
      "Centered content"
    },
    speaker_notes = {
      "<!--",
      "Speaker notes here",
      "-->"
    }
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
  
  if M.config.browser then
    cmd = M.config.browser .. " " .. url
  elseif vim.fn.has("mac") == 1 then
    cmd = "open " .. url
  elseif vim.fn.has("unix") == 1 then
    cmd = "xdg-open " .. url
  elseif vim.fn.has("win32") == 1 then
    cmd = "start " .. url
  else
    vim.notify("Could not detect browser", vim.log.levels.ERROR)
    return
  end
  
  vim.fn.jobstart(cmd, {detach = true})
end

-- List active servers
function M.list_active()
  if vim.tbl_isempty(M.active_processes) then
    vim.notify("No active Marp servers", vim.log.levels.INFO)
    return
  end
  
  local active = {}
  for bufnr, _ in pairs(M.active_processes) do
    local name = vim.api.nvim_buf_get_name(bufnr)
    table.insert(active, vim.fn.fnamemodify(name, ":t"))
  end
  
  vim.notify("Active Marp servers:\n" .. table.concat(active, "\n"), vim.log.levels.INFO)
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

-- Show tips
function M.show_tips()
  local tips = {
    "💡 Use :MarpExport pdf to export as PDF",
    "💡 Press :MarpTheme gaia to change theme",
    "💡 Use :MarpSnippet title for a title slide",
    "💡 Add '---' to create a new slide",
    "💡 Use :MarpInfo to see current settings",
    "💡 HTML path is copied to clipboard automatically"
  }
  
  -- Show a random tip
  math.randomseed(os.time())
  local tip = tips[math.random(#tips)]
  vim.notify(tip, vim.log.levels.INFO)
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

-- Debug function to test Marp command
function M.debug()
  local file = vim.api.nvim_buf_get_name(0)
  
  if file == "" or not file:match("%.md$") then
    vim.notify("Not a markdown file", vim.log.levels.ERROR)
    return
  end
  
  local marp_cmd = get_marp_cmd()
  local test_cmd = string.format("%s --version", marp_cmd)
  
  vim.notify("Testing Marp command...", vim.log.levels.INFO)
  
  -- Test if marp command works
  local shell_cmd = {"/bin/sh", "-c", test_cmd}
  vim.fn.jobstart(shell_cmd, {
    stdout_buffered = false,
    stderr_buffered = false,
    detach = true,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          vim.schedule(function()
            local clean_line = clean_ansi(line)
            vim.notify("Marp version: " .. clean_line, vim.log.levels.INFO)
          end)
        end
      end
    end,
    on_stderr = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          vim.schedule(function()
            local clean_line = clean_ansi(line)
            vim.notify("Error: " .. clean_line, vim.log.levels.ERROR)
          end)
        end
      end
    end,
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        vim.notify("Marp command failed with exit code: " .. exit_code, vim.log.levels.ERROR)
        vim.notify("Try installing with: npm install -g @marp-team/marp-cli", vim.log.levels.INFO)
      else
        vim.notify("✅ Marp command is working!", vim.log.levels.INFO)
        vim.notify("Debug mode: " .. (M.config.debug and "ON" or "OFF"), vim.log.levels.INFO)
        vim.notify("Command: " .. marp_cmd, vim.log.levels.INFO)
      end
    end
  })
end

return M