local Layout = require("nui.layout")
local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

local M = {}

local function display_diff(buf, diff)
	local lines = vim.split(diff, "\n")
	-- Clear existing content
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	-- Apply highlighting
	for i, line in ipairs(lines) do
		local highlight
		if line:match("^%+") then
			highlight = "DiffAdd"
		elseif line:match("^%-") then
			highlight = "DiffDelete"
		elseif line:match("^@@") then
			highlight = "DiffChange"
		else
			highlight = "Normal"
		end
		vim.api.nvim_buf_add_highlight(buf, -1, highlight, i - 1, 0, -1)
	end
end

local function setup_keymaps(popups, main_popup)
	local current_popup_index = 1

	local function cycle_popups(direction)
		-- Reset highlight of the current popup
		if popups[current_popup_index] then
			popups[current_popup_index].border:set_highlight("Normal")
		end

		-- Update the index
		current_popup_index = current_popup_index + direction
		if current_popup_index > #popups then
			current_popup_index = 1
		elseif current_popup_index < 1 then
			current_popup_index = #popups
		end

		-- Set focus to the new popup
		local cur_popup = popups[current_popup_index]
		vim.api.nvim_set_current_win(cur_popup.winid)

		-- Update the border highlight of the new focused popup
		cur_popup.border:set_highlight("FocusedFloatBorder")
	end

	local function close_popups()
		if main_popup then
			main_popup:unmount()
			main_popup = nil
		end
	end

	local function update_diff(file_buf, diff_buf, diff_win)
		local cursor = vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())
		local file = vim.api.nvim_buf_get_lines(file_buf, cursor[1] - 1, cursor[1], false)[1]

		-- Get the diff for the selected file
		local diff = vim.fn.system(string.format("git diff --cached -- %s", vim.fn.shellescape(file)))

		if vim.v.shell_error ~= 0 then
			diff = "Error: Unable to get diff for " .. file
		elseif diff == "" then
			diff = "No changes in " .. file
		end

		vim.api.nvim_buf_set_option(diff_buf, "modifiable", true)
		display_diff(diff_buf, diff)
		vim.api.nvim_set_current_win(diff_win)
	end

	vim.api.nvim_buf_set_keymap(popups[1].bufnr, "n", "<CR>", "", {
		callback = function()
			update_diff(popups[1].bufnr, popups[2].bufnr, popups[2].winid)
		end,
		noremap = true,
		silent = true,
	})

	local on_generate = function()
		local diff = vim.api.nvim_buf_get_lines(popups[2].bufnr, 0, -1, false)
		local diff_str = table.concat(diff, "\n")

		if diff_str == "" then
			vim.notify("No changes to commit", vim.log.levels.WARN)
			return
		end

		vim.api.nvim_buf_set_lines(popups[3].bufnr, 0, -1, false, { "Generating commit message..." })
		vim.schedule(function()
			local commit_message = require("mai_pull_request.openai").generate_commit_message(diff_str)
			vim.api.nvim_buf_set_lines(popups[3].bufnr, 0, -1, false, vim.split(commit_message, "\n"))
			vim.api.nvim_buf_set_option(popups[3].bufnr, "wrap", true)
			vim.api.nvim_set_current_win(popups[3].winid)
		end)
	end
	-- Map keys for each popup
	for _, popup in ipairs(popups) do
		popup:map("n", "<Tab>", function()
			cycle_popups(1)
		end, { noremap = true, silent = true })
		popup:map("n", "<S-Tab>", function()
			cycle_popups(-1)
		end, { noremap = true, silent = true })
		popup:map("n", "q", close_popups, { noremap = true, silent = true })
		popup:map("n", "g", on_generate, { noremap = true, silent = true })
	end

  cycle_popups(0)
end

local function create_main_popup()
	local popup_options = {
		enter = true,
		focusable = true,
		border = {
			style = "rounded",
		},
		win_options = {
			winblend = 10,
			winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
		},
	}

	local top_left_popup = Popup(vim.tbl_extend("force", popup_options, {
		border = {
			text = {
				top = "Files Changed",
				top_align = "left",
			},
			style = "rounded",
		},
	}))

	local top_right_popup = Popup(vim.tbl_extend("force", popup_options, {
		border = {
			text = {
				top = "Selected File Diff",
				top_align = "left",
			},
			style = "rounded",
		},
	}))

	local bottom_popup = Popup(vim.tbl_extend("force", popup_options, {
		border = "rounded",
		focusable = false,
	}))

	local bottom_inner_popup = Popup(vim.tbl_extend("force", popup_options, {
		border = {
			text = {
				top = "Commit Message",
				top_align = "left",
			},
			style = "rounded",
		},
	}))

	local main_popup = Layout(
		{
			position = "50%",
			size = {
				width = "80%",
				height = "60%",
			},
		},
		Layout.Box({
			Layout.Box({
				Layout.Box(top_left_popup, { size = "50%" }),
				Layout.Box(top_right_popup, { size = "50%" }),
			}, { dir = "row", size = "30%" }),
			Layout.Box({
				Layout.Box(bottom_inner_popup, { size = "50%" }),
				Layout.Box(bottom_popup, { size = "10%" }),
			}, { dir = "col", size = "60%" }),
		}, { dir = "col" })
	)

	return main_popup, top_left_popup, top_right_popup, bottom_popup, bottom_inner_popup
end

local function setup_events(popup)
	local function highlight_current_line()
		local bufnr = popup.bufnr
		local current_line = vim.api.nvim_win_get_cursor(popup.winid)[1] - 1

		-- Clear previous highlights
		vim.api.nvim_buf_clear_namespace(bufnr, -1, 0, -1)

		-- Add highlight to the current line
		vim.api.nvim_buf_add_highlight(bufnr, -1, "Visual", current_line, 0, -1)
	end

	popup:on(event.CursorMoved, highlight_current_line)
	popup:on(event.CursorMovedI, highlight_current_line)
	highlight_current_line()
end

function M.view_diff()
	local main_popup, top_left_popup, top_right_popup, bottom_popup, bottom_inner_popup = create_main_popup()
	main_popup:mount()

	local popups = { top_left_popup, top_right_popup, bottom_inner_popup }
	setup_keymaps(popups, main_popup)
	setup_events(top_left_popup)

	local staged_data = require("mai_pull_request.git").get_staged_diff()
	if not staged_data then
		vim.api.nvim_buf_set_lines(top_left_popup.bufnr, 0, -1, false, { "No changes staged" })
	else
		vim.api.nvim_buf_set_lines(top_left_popup.bufnr, 0, -1, false, staged_data.files)
		display_diff(top_right_popup.bufnr, staged_data.diff)
	end

	vim.api.nvim_buf_set_lines(bottom_popup.bufnr, 0, -1, false, { "[g] - generate commit message | [c] - commit" })
end

return M
