local cli = require("marp.cli")

local M = {}

function M.check()
  vim.health.start("marp.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim " .. tostring(vim.version()))
  else
    vim.health.error("Neovim 0.10 or newer is required")
    return
  end

  local marp = require("marp")
  local config = marp.config
  local command = cli.resolve_command(config.marp_command)
  local executable = command[1]

  if vim.fn.executable(executable) ~= 1 then
    vim.health.error("Marp command is not executable: " .. executable, {
      "Install @marp-team/marp-cli or configure marp_command.",
    })
    return
  end
  vim.health.ok("Marp command is executable: " .. executable)

  local file = vim.api.nvim_buf_get_name(0)
  local config_path
  local project_root
  local version_options = { "--version", "--no-stdin" }

  if config.config_file == false then
    table.insert(version_options, "--no-config-file")
    if file ~= "" then
      project_root = vim.fn.fnamemodify(file, ":p:h")
    end
    vim.health.info("Marp config discovery is disabled")
  elseif type(config.config_file) == "string" and config.config_file ~= "" then
    config_path = vim.fn.fnamemodify(config.config_file, ":p")
    project_root = vim.fn.fnamemodify(config_path, ":h")
    table.insert(version_options, "--config-file")
    table.insert(version_options, config_path)
    vim.health.info("Explicit Marp config: " .. config_path)
  elseif file ~= "" then
    config_path, project_root = cli.find_config(file)
    if config_path then
      vim.health.info("Detected Marp config: " .. config_path)
    else
      vim.health.info("No project Marp config detected for the current buffer")
    end
  end

  local version_args = cli.build_argv(command, version_options)
  local ok, result = pcall(function()
    return vim
      .system(version_args, {
        cwd = project_root,
        text = true,
        env = cli.process_env(config),
        timeout = 5000,
      })
      :wait()
  end)

  if not ok then
    vim.health.error("Could not run Marp CLI: " .. tostring(result))
  elseif result.code == 0 then
    vim.health.ok(vim.trim(result.stdout or "Marp CLI version check passed"))
    if config_path then
      vim.health.ok("Marp config is loadable: " .. config_path)
    end
  else
    vim.health.error("Marp CLI version/config check failed: " .. vim.trim(result.stderr or "unknown error"))
  end

  if type(config.marp_command) == "string" and config.marp_command:match("%s") then
    vim.health.warn("marp_command contains arguments in a string", {
      'Prefer an argv list, e.g. { "npx", "@marp-team/marp-cli@latest" }.',
    })
  end

  if config.no_stdin == false then
    vim.health.warn("no_stdin is disabled; Marp may wait on Neovim's stdin pipe")
  else
    vim.health.ok("File-based commands disable Marp CLI stdin")
  end

  if config.allow_local_files then
    vim.health.warn("allow_local_files is enabled", {
      "Only open trusted slide decks because rendered Markdown can access local files.",
    })
  end
end

return M
