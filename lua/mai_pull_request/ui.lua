local M = {}

-- Function to create a floating window
local function create_float_window()
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	local buf = vim.api.nvim_create_buf(false, true)
	local opts = {
		style = "minimal",
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		border = "rounded",
	}
	local win = vim.api.nvim_open_win(buf, true, opts)
	return buf, win
end

-- Function to create a split within the main window
local function create_split(parent_win, width, height, row, col)
	local buf = vim.api.nvim_create_buf(false, true)
	local opts = {
		style = "minimal",
		relative = "win",
		win = parent_win,
		width = width,
		height = height,
		row = row,
		col = col,
		focusable = true,
	}
	local win = vim.api.nvim_open_win(buf, false, opts)
	return buf, win
end

-- Function to display file list
local function display_file_list(buf, files)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, files)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

-- Function to display diff
local function display_diff(buf, diff)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(diff, "\n"))
	vim.api.nvim_buf_set_option(buf, "filetype", "diff")
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

-- Function to update diff based on selected file
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

-- Function to display the staged diff
function M.display_staged_diff()
	local staged_data, error_msg = require("mai_pull_request").get_staged_diff()
	if not staged_data then
		vim.api.nvim_err_writeln("Error: " .. (error_msg or "Unknown error"))
		return
	end

	-- Use the complex float window to display the diff
	M.create_complex_float(staged_data.files, staged_data.diff)
end

-- Function to display the generated commit message
function M.display_commit_message(message)
	local buf, win = create_float_window()

	-- Set buffer options
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	-- Set content
	local lines = vim.split(message, "\n")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	-- Set keymap to close the window
	vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { noremap = true, silent = true })
	-- Set window options
	vim.api.nvim_win_set_option(win, "wrap", true)
	vim.api.nvim_win_set_option(win, "cursorline", false)
	-- Set buffer name
	vim.api.nvim_buf_set_name(buf, "Generated Commit Message")
end

-- Main function to create the complex float window
function M.create_complex_float(files, initial_diff)
	local main_buf, main_win = create_float_window()
	local main_width = vim.api.nvim_win_get_width(main_win)
	local main_height = vim.api.nvim_win_get_height(main_win)

	-- Create file list split
	local file_buf, file_win = create_split(main_win, math.floor(main_width * 0.3), math.floor(main_height * 0.7), 0, 0)
	display_file_list(file_buf, files or { "No staged files" })

	-- Create diff split
	local diff_buf, diff_win = create_split(
		main_win,
		math.floor(main_width * 0.7) - 1,
		math.floor(main_height * 0.7),
		0,
		math.floor(main_width * 0.3) + 1
	)
	display_diff(diff_buf, initial_diff or "Select a file to view diff")

	-- Create bottom panel
	local bottom_buf, bottom_win =
		create_split(main_win, main_width, math.floor(main_height * 0.3) - 1, math.floor(main_height * 0.7) + 1, 0)
	vim.api.nvim_buf_set_lines(
		bottom_buf,
		0,
		-1,
		false,
		{ "Press 'g' to generate commit message", "Press 'y' to copy generated commit to clipboard" }
	)
	-- Set up keymaps for navigation between splits
	local function create_navigation_keymap(from_win, to_win, key)
		vim.api.nvim_buf_set_keymap(vim.api.nvim_win_get_buf(from_win), "n", "<C-" .. key .. ">", "", {
			callback = function()
				vim.api.nvim_set_current_win(to_win)
			end,
			noremap = true,
			silent = true,
		})
	end

	-- Navigation keymaps
	create_navigation_keymap(file_win, diff_win, "l")
	create_navigation_keymap(diff_win, file_win, "h")
	create_navigation_keymap(file_win, bottom_win, "j")
	create_navigation_keymap(diff_win, bottom_win, "j")
	create_navigation_keymap(bottom_win, file_win, "k")
	create_navigation_keymap(bottom_win, diff_win, "l")

	-- Set up keymaps
	vim.api.nvim_buf_set_keymap(file_buf, "n", "<CR>", "", {
		callback = function()
			update_diff(file_buf, diff_buf, diff_win)
		end,
		noremap = true,
		silent = true,
	})

	local function generate_commit_message()
    -- Call the generate_commit_message function from the openai.lua file
    local commit_message = require("mai_pull_request.openai").generate_commit_message(initial_diff)
    display_diff(bottom_buf, commit_message)
	end

	vim.api.nvim_buf_set_keymap(bottom_buf, "n", "gcm", "", {
		callback = function()
			generate_commit_message()
		end,
		noremap = true,
		silent = true,
		desc = "Generate commit message",
	})

	vim.api.nvim_buf_set_keymap(bottom_buf, "n", "y", "", {
		callback = function()
			print("Copy commit to clipboard")
		end,
		noremap = true,
		silent = true,
	})

	-- Function to safely close a window
	local function safe_close(win_id)
		if vim.api.nvim_win_is_valid(win_id) then
			vim.api.nvim_win_close(win_id, true)
		end
	end

	-- Function to close all windows
	local function close_all_windows()
		safe_close(file_win)
		safe_close(diff_win)
		safe_close(bottom_win)
		safe_close(main_win)
	end

	-- Set up 'q' keymap for all buffers
	for _, buf in ipairs({ main_buf, file_buf, diff_buf, bottom_buf }) do
		vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
			callback = close_all_windows,
			noremap = true,
			silent = true,
		})
	end

	-- Modify the WinClosed autocmd
	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(main_win),
		callback = function()
			-- Delay the execution slightly to allow for the current window close operation to complete
			vim.schedule(close_all_windows)
		end,
	})
	-- Set initial focus to file list
	vim.api.nvim_set_current_win(file_win)
end

return M
