local marp = require("marp")

local function assert_true(value, message)
  if not value then
    error(message)
  end
end

local temp_root = vim.fn.tempname() .. " marp.nvim"
vim.fn.mkdir(temp_root, "p")

local deck = temp_root .. "/deck's test.md"
local exported = temp_root .. "/exported deck.html"
vim.fn.writefile({ "---", "marp: true", "---", "# Integration test", "---", "# Second slide" }, deck)
vim.cmd.edit(vim.fn.fnameescape(deck))

marp.setup({
  marp_command = { "marp" },
  allow_local_files = false,
  auto_copy_path = false,
  show_file_size = false,
  suggest_gitignore = false,
  debug = false,
})

-- Covers argv paths with spaces/apostrophes and the --no-stdin regression.
marp.export("html", exported)
assert_true(
  vim.wait(10000, function()
    return vim.fn.filereadable(exported) == 1 and marp.metadata.last_export.format == "html"
  end, 20),
  "Marp export did not finish"
)

-- Issue #3 affected every file-based action. Exercise preview, thumbnail, and
-- regular watch mode without a marp_command workaround.
local opened_url
local original_open_browser = marp.open_browser
marp.open_browser = function(url)
  opened_url = url
end

local buffer_deck = vim.api.nvim_buf_get_name(0)
local preview_html = buffer_deck:gsub("%.md$", ".html")
marp.preview()
assert_true(
  vim.wait(10000, function()
    return vim.fn.filereadable(preview_html) == 1 and opened_url ~= nil
  end, 20),
  "Marp preview did not finish"
)
assert_true(opened_url == vim.uri_from_fname(preview_html), "Marp preview opened an unexpected URL")

local thumbnail = buffer_deck:gsub("%.md$", ".png")
local previous_export = marp.metadata.last_export
marp.thumbnail("png")
assert_true(
  vim.wait(15000, function()
    return vim.fn.filereadable(thumbnail) == 1
      and marp.metadata.last_export ~= previous_export
      and marp.metadata.last_export.format == "thumbnail_png"
  end, 20),
  "Marp thumbnail did not finish"
)

opened_url = nil
marp.setup({ server_mode = false })
local watcher_ready = false
local original_notify = vim.notify
vim.notify = function(message, level, opts)
  if tostring(message):find("[Watch mode] Start watching", 1, true) then
    watcher_ready = true
  end
  return original_notify(message, level, opts)
end
marp.watch()
assert_true(
  vim.wait(10000, function()
    return watcher_ready and opened_url ~= nil and marp.active_processes[vim.api.nvim_get_current_buf()] ~= nil
  end, 20),
  "Marp watch did not start"
)
assert_true(opened_url == vim.uri_from_fname(preview_html), "Marp watch opened an unexpected URL")

local watch_marker = "Issue 3 watch update"
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "---",
  "marp: true",
  "---",
  "# Integration test",
  "",
  watch_marker,
  "",
  "---",
  "",
  "# Second slide",
})
vim.cmd.write()
assert_true(
  vim.wait(10000, function()
    local html = table.concat(vim.fn.readfile(preview_html), "\n")
    return html:find(watch_marker, 1, true) ~= nil
  end, 20),
  "Marp watch did not rebuild HTML after the deck changed"
)

marp.stop()
assert_true(
  vim.wait(2000, function()
    return marp.active_processes[vim.api.nvim_get_current_buf()] == nil
  end, 20),
  "Marp watch did not stop"
)
vim.notify = original_notify

-- Multi-image exports must report the numbered files Marp actually creates.
local image_output = temp_root .. "/rendered slides.png"
marp.export("png", image_output)
local first_image = temp_root .. "/rendered slides.001.png"
local second_image = temp_root .. "/rendered slides.002.png"
assert_true(
  vim.wait(15000, function()
    return vim.fn.filereadable(first_image) == 1
      and vim.fn.filereadable(second_image) == 1
      and marp.metadata.last_export.format == "png"
  end, 20),
  "Marp multi-image export did not finish"
)
assert_true(
  vim.deep_equal(marp.metadata.last_export.files, { first_image, second_image }),
  "Multi-image export metadata did not contain the numbered output paths"
)

-- Marp leaves obsolete numbered files in place when a deck gets shorter.
-- A subsequent export must report only files written by that invocation.
vim.fn.writefile({ "---", "marp: true", "---", "# One slide now" }, deck)
previous_export = marp.metadata.last_export
marp.export("png", image_output)
assert_true(
  vim.wait(15000, function()
    return marp.metadata.last_export ~= previous_export
  end, 20),
  "Marp image re-export did not finish"
)
assert_true(vim.fn.filereadable(second_image) == 1, "Marp unexpectedly removed the stale second image")
assert_true(
  vim.deep_equal(marp.metadata.last_export.files, { first_image }),
  "Image re-export metadata included a stale numbered output"
)

-- Server mode must serve the deck directory, not pass the Markdown file to -s.
local tcp = assert(vim.uv.new_tcp())
assert(tcp:bind("127.0.0.1", 0))
local port = assert(tcp:getsockname()).port
tcp:close()

local previous_port = vim.env.PORT
vim.env.PORT = tostring(port)
opened_url = nil

marp.setup({ server_mode = true })
marp.watch()
assert_true(
  vim.wait(10000, function()
    return opened_url ~= nil
  end, 20),
  "Marp server did not publish a preview URL"
)
assert_true(
  opened_url == string.format("http://localhost:%d/deck%%27s%%20test.md", port),
  "Unexpected Marp server URL: " .. tostring(opened_url)
)

marp.stop()
assert_true(
  vim.wait(2000, function()
    return marp.active_processes[vim.api.nvim_get_current_buf()] == nil
  end, 20),
  "Marp server did not stop"
)
marp.open_browser = original_open_browser
vim.env.PORT = previous_port
vim.fn.delete(temp_root, "rf")

print("marp integration tests passed")
