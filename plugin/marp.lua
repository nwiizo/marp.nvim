if vim.g.loaded_marp then
  return
end
vim.g.loaded_marp = true

if vim.fn.has("nvim-0.10") ~= 1 then
  vim.notify("marp.nvim requires Neovim 0.10 or newer", vim.log.levels.ERROR)
  return
end

local function command(name, method, opts)
  vim.api.nvim_create_user_command(name, function()
    require("marp")[method]()
  end, opts)
end

local function first_arg_completion(items)
  return function(arg_lead, cmd_line)
    local rest = cmd_line:match("^%S+%s*(.*)$") or ""
    local before_current = rest:sub(1, #rest - #arg_lead)
    if before_current:match("%S") then
      return {}
    end

    return vim.tbl_filter(function(item)
      return vim.startswith(item, arg_lead)
    end, items)
  end
end

command("MarpWatch", "watch", { desc = "Start a live Marp preview" })
command("MarpStop", "stop", { desc = "Stop Marp for the current buffer" })
command("MarpStopAll", "stop_all", { desc = "Stop all Marp processes" })
command("MarpPreview", "preview", { desc = "Generate and open a one-time Marp preview" })
command("MarpList", "list_active", { desc = "List active Marp processes" })
command("MarpInfo", "info", { desc = "Show information about the current Marp deck" })
command("MarpCopyPath", "copy_html_path", { desc = "Copy the generated HTML path" })
command("MarpConfig", "open_config", { desc = "Open the detected Marp CLI config" })
command("MarpDebug", "debug", { desc = "Run Marp diagnostics" })

vim.api.nvim_create_user_command("MarpExport", function(args)
  if #args.fargs > 2 then
    vim.notify("Usage: MarpExport [format] [output]", vim.log.levels.ERROR)
    return
  end
  require("marp").export(args.fargs[1], args.fargs[2])
end, {
  nargs = "*",
  complete = first_arg_completion({ "html", "pdf", "pptx", "png", "jpeg", "notes" }),
  desc = "Export the current Marp deck: [format] [output]",
})

vim.api.nvim_create_user_command("MarpThumbnail", function(args)
  require("marp").thumbnail(args.fargs[1])
end, {
  nargs = "?",
  complete = first_arg_completion({ "png", "jpeg" }),
  desc = "Generate a thumbnail from the first slide",
})

vim.api.nvim_create_user_command("MarpTheme", function(args)
  require("marp").set_theme(args.args)
end, {
  nargs = 1,
  complete = first_arg_completion({ "default", "gaia", "uncover" }),
  desc = "Set the current deck theme",
})

vim.api.nvim_create_user_command("MarpSnippet", function(args)
  require("marp").insert_snippet(args.args)
end, {
  nargs = 1,
  complete = first_arg_completion({ "title", "columns", "image", "bg_image", "center", "speaker_notes" }),
  desc = "Insert a Marp snippet",
})

local augroup = vim.api.nvim_create_augroup("marp.nvim", { clear = true })
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = augroup,
  desc = "Stop Marp processes before Neovim exits",
  callback = function()
    local loaded = package.loaded.marp
    if loaded then
      loaded.stop_all(true)
    end
  end,
})
