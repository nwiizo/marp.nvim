local cli = require("marp.cli")

local function assert_equal(expected, actual, message)
  if not vim.deep_equal(expected, actual) then
    error(
      string.format(
        "%s\nexpected: %s\nactual:   %s",
        message or "values differ",
        vim.inspect(expected),
        vim.inspect(actual)
      )
    )
  end
end

local function assert_contains(values, expected, message)
  for _, value in ipairs(values) do
    if value == expected then
      return
    end
  end
  error((message or "value not found") .. ": " .. vim.inspect(expected))
end

local function assert_not_contains(values, unexpected, message)
  for _, value in ipairs(values) do
    if value == unexpected then
      error((message or "unexpected value found") .. ": " .. vim.inspect(unexpected))
    end
  end
end

local temp_root = vim.fn.tempname()
vim.fn.mkdir(temp_root .. "/project/slides/nested", "p")
vim.fn.writefile({ "---", "marp: true", "---", "# Test" }, temp_root .. "/project/slides/nested/deck.md")

-- Match Marp CLI / cosmiconfig discovery, including TypeScript configs.
local ts_config = temp_root .. "/project/marp.config.ts"
vim.fn.writefile({ "export default {}" }, ts_config)
local found_path, found_root = cli.find_config(temp_root .. "/project/slides/nested/deck.md")
assert_equal(ts_config, found_path, "finds marp.config.ts from a nested deck")
assert_equal(temp_root .. "/project", found_root, "uses the config directory as project root")

-- package.json is a config only when it has a top-level marp property.
vim.fn.delete(ts_config)
vim.fn.writefile({ '{"name":"slides"}' }, temp_root .. "/project/package.json")
found_path, found_root = cli.find_config(temp_root .. "/project/slides/nested/deck.md")
assert_equal(nil, found_path, "ignores package.json without a marp property")
assert_equal(temp_root .. "/project/slides/nested", found_root, "falls back to the deck directory")

vim.fn.writefile({ '{"name":"slides","marp":{"html":true}}' }, temp_root .. "/project/package.json")
found_path, found_root = cli.find_config(temp_root .. "/project/slides/nested/deck.md")
assert_equal(temp_root .. "/project/package.json", found_path, "finds package.json with a marp property")
assert_equal(temp_root .. "/project", found_root, "uses the package directory as project root")

-- Every file-based invocation disables hidden stdin input by default.
local common = cli.common_args({
  no_stdin = true,
  theme_set = { "/tmp/theme with spaces.css" },
  browser_kind = { "firefox", "chrome" },
  browser_protocol = "webdriver-bidi",
  browser_timeout = 45,
  bespoke_progress = true,
})
assert_equal("--no-stdin", common[1], "puts --no-stdin on every invocation")
assert_contains(common, "firefox,chrome", "serializes browser preference lists")
assert_contains(common, "webdriver-bidi", "adds browser protocol")
assert_contains(common, "--bespoke.progress=true", "adds boolean template options")

local without_stdin_guard = cli.common_args({ no_stdin = false })
assert_equal({}, without_stdin_guard, "allows wrappers to opt out of --no-stdin")

local pdf = cli.export_args({
  pdf_notes = true,
  pdf_outlines = true,
  pdf_outlines_pages = false,
  pdf_outlines_headings = true,
  image_scale = 1,
  jpeg_quality = 85,
}, "pdf")
assert_equal({
  "--pdf-notes",
  "--pdf-outlines",
  "--pdf-outlines.pages=false",
  "--pdf-outlines.headings=true",
}, pdf, "builds granular PDF outline options")

-- argv execution preserves shell metacharacters without invoking a shell.
local special_path = "/tmp/O'Reilly theme $HOME.css"
assert_equal(
  { "printf", "%s", special_path },
  cli.build_argv({ "printf", "%s" }, { special_path }),
  "preserves every generated argument"
)
assert_equal(
  { "npx", "@marp-team/marp-cli@latest" },
  cli.command_argv("npx @marp-team/marp-cli@latest"),
  "keeps backward compatibility with string commands"
)

-- The startup file should register commands without eagerly loading marp.lua.
package.loaded.marp = nil
vim.cmd.runtime("plugin/marp.lua")
assert_equal(nil, package.loaded.marp, "plugin entrypoint defers requiring the main module")
assert_equal(2, vim.fn.exists(":MarpExport"), "registers MarpExport")
assert_equal(2, vim.fn.exists(":MarpConfig"), "registers MarpConfig")
local commands = vim.api.nvim_get_commands({})
assert_equal(
  "Export the current Marp deck: [format] [output]",
  commands.MarpExport.definition,
  "adds command descriptions"
)

local marp = require("marp")
assert_equal(true, marp.config.no_stdin, "disables Marp stdin in the default configuration")
marp.setup({ browser_kind = { "firefox", "chrome" }, theme_set = { "first.css", "second.css" } })
marp.setup({ browser_kind = { "edge" }, theme_set = { "replacement.css" } })
assert_equal({ "edge" }, marp.config.browser_kind, "setup replaces argv-style lists instead of deep-merging them")
assert_equal({ "replacement.css" }, marp.config.theme_set, "setup replaces theme_set as a list")
local valid, validation_error = pcall(marp.setup, { jpeg_quality = 101 })
assert_equal(false, valid, "rejects an invalid JPEG quality")
assert(validation_error:match("jpeg_quality"), "validation error identifies the invalid option")

-- custom_theme remains a preview/export default, but frontmatter takes precedence.
local preview_deck = temp_root .. "/project/slides/nested/deck.md"
vim.cmd.edit(vim.fn.fnameescape(preview_deck))
local captured_argv
local original_system = vim.system
vim.system = function(argv)
  captured_argv = argv
  return {}
end
marp.setup({ custom_theme = "custom.css" })
marp.preview()
assert_contains(captured_argv, "--theme", "passes custom_theme to preview")
assert_contains(captured_argv, "custom.css", "passes the configured custom theme")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "---", "marp: true", "theme: gaia", "---", "# Test" })
marp.preview()
vim.system = original_system
assert_not_contains(captured_argv, "--theme", "frontmatter theme takes precedence over custom_theme")
vim.bo.modified = false

-- An explicit desktop opener takes precedence over vim.ui.open().
original_system = vim.system
local original_ui_open = vim.ui.open
local opened_argv
local default_open_called = false
vim.system = function(argv)
  opened_argv = argv
  return {}
end
vim.ui.open = function()
  default_open_called = true
end
marp.config.browser = { "custom-browser", "--new-window" }
marp.open_browser("https://example.test/deck")
vim.system = original_system
vim.ui.open = original_ui_open
marp.config.browser = nil
assert_equal(
  { "custom-browser", "--new-window", "https://example.test/deck" },
  opened_argv,
  "uses the configured desktop opener"
)
assert_equal(false, default_open_called, "does not call vim.ui.open when browser is configured")

-- Health checks must load the config belonging to the current deck.
local health_root = temp_root .. "/health-project"
local health_deck = health_root .. "/slides/deck.md"
local health_config = health_root .. "/marp.config.mjs"
vim.fn.mkdir(health_root .. "/slides", "p")
vim.fn.writefile({ "export default {}" }, health_config)
vim.fn.writefile({ "---", "marp: true", "---", "# Health" }, health_deck)
vim.cmd.edit(vim.fn.fnameescape(health_deck))
marp.setup({ marp_command = { "printf" } })

local health_argv
local health_options
local health_messages = {}
local original_health = {}
for _, method in ipairs({ "start", "ok", "error", "warn", "info" }) do
  original_health[method] = vim.health[method]
  vim.health[method] = function(message)
    table.insert(health_messages, tostring(message))
  end
end

original_system = vim.system
vim.system = function(argv, opts)
  health_argv = argv
  health_options = opts
  return {
    wait = function()
      return { code = 0, stdout = "@marp-team/marp-cli v4.5.0" }
    end,
  }
end

local health_ok, health_error = pcall(require("marp.health").check)
vim.system = original_system
for method, original in pairs(original_health) do
  vim.health[method] = original
end

assert(health_ok, health_error)
assert_equal({ "printf", "--version", "--no-stdin" }, health_argv, "builds a config-aware version check")
assert_equal(vim.uv.fs_realpath(health_root), health_options.cwd, "runs the version check from the deck's project root")
assert_contains(
  health_messages,
  "Marp config is loadable: " .. vim.uv.fs_realpath(health_config),
  "reports a loadable project config"
)

-- Automatic retries preserve the current count instead of resetting forever.
local retry_deck = preview_deck
vim.cmd.edit(vim.fn.fnameescape(retry_deck))
local bufnr = vim.api.nvim_get_current_buf()
marp.setup({
  marp_command = { "sh", "-c", "exit 7" },
  server_mode = true,
  auto_copy_path = false,
  suggest_gitignore = false,
})
marp.metadata.process_generations[bufnr] = 42
marp.metadata.process_retries[bufnr] = 3
local original_notify = vim.notify
vim.notify = function() end
marp.watch(42)
assert(
  vim.wait(1000, function()
    return marp.active_processes[bufnr] == nil
  end, 10),
  "failing Marp process did not exit"
)
vim.notify = original_notify
assert_equal(3, marp.metadata.process_retries[bufnr], "keeps the retry count at its limit")

vim.fn.delete(temp_root, "rf")
print("marp CLI tests passed")
