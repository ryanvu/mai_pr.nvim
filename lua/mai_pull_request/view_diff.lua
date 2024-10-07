local Layout = require("nui.layout")
local Popup = require("nui.popup")

local M = {}

local function setup_keymaps(popups, main_popup)
	local current_popup_index = 1

	local function cycle_popups(direction)
		current_popup_index = current_popup_index + direction
		if current_popup_index > #popups then
			current_popup_index = 1
		elseif current_popup_index < 1 then
			current_popup_index = #popups
		end
		vim.api.nvim_set_current_win(popups[current_popup_index].winid)
	end

	local function close_popups()
		if main_popup then
			main_popup:unmount()
			main_popup = nil
		end
	end

	-- Set initial focus to top left popup
	vim.api.nvim_set_current_win(popups[1].winid)

	-- Map keys for each popup
	for _, popup in ipairs(popups) do
		popup:map("n", "<Tab>", function()
			cycle_popups(1)
		end, { noremap = true, silent = true })
		popup:map("n", "<S-Tab>", function()
			cycle_popups(-1)
		end, { noremap = true, silent = true })
		popup:map("n", "q", close_popups, { noremap = true, silent = true })
	end
end

local function create_main_popup()
	local popup_options = {
		enter = true,
		focusable = true,
		border = {
			style = "rounded",
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
				height = "80%",
			},
		},
		Layout.Box({
			Layout.Box({
				Layout.Box(top_left_popup, { size = "50%" }),
				Layout.Box(top_right_popup, { size = "50%" }),
			}, { dir = "row", size = "30%" }),
			Layout.Box(bottom_popup, { size = "70%" }),
		}, { dir = "col" })
	)

	return main_popup, top_left_popup, top_right_popup, bottom_popup
end

function M.view_diff()
	local main_popup, top_left_popup, top_right_popup, bottom_popup = create_main_popup()
	main_popup:mount()

	local popups = { top_left_popup, top_right_popup, bottom_popup }
	setup_keymaps(popups, main_popup)

	-- Setup Top Left Popup (Files Changes)
	local staged_data = require("mai_pull_request").get_staged_diff()
	if not staged_data then
		vim.nvim_buf_set_lines(top_left_popup.bufnr, 0, -1, false, { "No changes staged" })
	else
    vim.notify(staged_data.files[0])
		vim.nvim_buf_set_lines(top_left_popup.bufnr, 0, -1, false, staged_data.files)
	end
end

return M
