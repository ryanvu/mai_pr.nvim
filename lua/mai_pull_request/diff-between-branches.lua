local Layout = require("nui.layout")
local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

local M = {}

local function get_diff_between_branches(branch1, branch2)
	local cmd = string.format("git diff %s..%s", branch1, branch2)
	local handle = io.popen(cmd)
	local result = handle:read("*a")
	handle:close()
	return result
end

local function get_list_branches()
	local handle = io.popen("git branch")
	local result = handle:read("*a")
	handle:close()
	return vim.split(result, "\n")
end

local function get_current_branch()
	local handle = io.popen("git branch --show-current")
	local result = handle:read("*a")
	handle:close()
	return vim.split(result, "\n")
end

local function create_confirmation_popup()
	local popup = Popup({
		enter = true,
		focusable = true,
		border = {
			style = "rounded",
			text = {
				top = "Confirm Branch Selection",
				top_align = "center",
			},
		},
		position = "50%",
		size = {
			width = "100%",
			height = "100%",
		},
		buf_options = {
			modifiable = true,
			readonly = false,
		},
	})

	return popup
end

local function create_main_popup()
	local popup_options = {
		enter = true,
		focusable = true,
		border = {
			style = "rounded",
		},
		buf_options = {
			modifiable = true,
			readonly = false,
		},
	}

	local left_popup = Popup(vim.tbl_extend("force", popup_options, {
		border = {
			text = {
				top = "Current Branch",
				top_align = "center",
			},
			style = "rounded",
		},
	}))

	local right_popup = Popup(vim.tbl_extend("force", popup_options, {
		border = {
			text = {
				top = "Branches to compare",
				top_align = "center",
			},
			style = "rounded",
		},
	}))

	local main_popup = Layout(
		{
			position = "50%",
			size = {
				width = "30%",
				height = "50%",
			},
		},
		Layout.Box({
			Layout.Box(left_popup, { size = "10%" }),
			Layout.Box(right_popup, { size = "30%" }),
		}, { dir = "col" })
	)
	return main_popup, left_popup, right_popup
end

function M.show_branches()
	local current_branch = get_current_branch()
	local branches = get_list_branches()

	local main_popup, left_popup, right_popup = create_main_popup()
	main_popup:mount()

	vim.api.nvim_buf_set_lines(left_popup.bufnr, 0, -1, false, current_branch)
	vim.api.nvim_buf_set_option(left_popup.bufnr, "modifiable", false)
	vim.api.nvim_buf_set_option(left_popup.bufnr, "readonly", true)

	vim.api.nvim_buf_set_lines(right_popup.bufnr, 0, -1, false, branches)
	vim.api.nvim_buf_set_option(right_popup.bufnr, "modifiable", false)
	vim.api.nvim_buf_set_option(right_popup.bufnr, "readonly", true)
	-- Set to the right popup, as you dont need to navigate for the present branch
	vim.api.nvim_set_current_win(right_popup.winid)

	local close_popups = function()
		if M.confirmation_popup then
			M.confirmation_popup:unmount()
			M.confirmation_popup = nil
		end
		main_popup:unmount()
	end

	local show_confirmation = function(selected_branch)
		M.confirmation_popup = create_confirmation_popup()
		M.confirmation_popup:mount()

    local cur_branch = vim.trim(current_branch[1])
		-- Set content for confirmation popup
		local lines = {
      "Please confirm these are the branches you want the diff between",
			"",
      "git diff " .. selected_branch .. " ---> " .. cur_branch,
			"",
			"Press Y to confirm, N to cancel",
		}
		vim.api.nvim_buf_set_lines(M.confirmation_popup.bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(M.confirmation_popup.bufnr, "modifiable", false)
    vim.api.nvim_buf_set_option(M.confirmation_popup.bufnr, "readonly", true)

		-- Confirmation popup keymaps
		local confirm = function()
			close_popups()
			local diff = get_diff_between_branches(current_branch, selected_branch)
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(diff, "\n"))
			vim.bo.filetype = "diff"
			vim.bo.modifiable = false
			vim.bo.readonly = true
			vim.api.nvim_buf_set_name(0, string.format("Diff: %s..%s", current_branch, selected_branch))
		end

		local cancel = function()
			M.confirmation_popup:unmount()
			M.confirmation_popup = nil
		end

		M.confirmation_popup:map("n", "y", confirm, { noremap = true })
		M.confirmation_popup:map("n", "Y", confirm, { noremap = true })
		M.confirmation_popup:map("n", "n", cancel, { noremap = true })
		M.confirmation_popup:map("n", "N", cancel, { noremap = true })
		M.confirmation_popup:map("n", "<Esc>", cancel, { noremap = true })
	end

	local select_branch = function()
		local line = vim.api.nvim_win_get_cursor(right_popup.winid)[1]
		local selected_branch = vim.trim(branches[line])
		local cur_branch = vim.trim(current_branch[1])
		-- Remove the leading "* " if it's the current branch
		selected_branch = selected_branch:gsub("^%* ", "")

		if selected_branch ~= "" and selected_branch ~= cur_branch then
			local diff = get_diff_between_branches(selected_branch, cur_branch)
			show_confirmation(selected_branch)
		else
			print("Invalid selection or same as current branch")
		end
	end

	-- Bind keys
	local maps = {
		["<Esc>"] = close_popups,
		q = close_popups,
		["<CR>"] = select_branch,
	}

	for key, func in pairs(maps) do
		right_popup:map("n", key, func, { noremap = true })
	end

	-- Disable insert mode in both popups
	local disable_insert = function()
		vim.cmd("stopinsert")
	end

	left_popup:on(event.InsertEnter, disable_insert)
	right_popup:on(event.InsertEnter, disable_insert)
end

return M
