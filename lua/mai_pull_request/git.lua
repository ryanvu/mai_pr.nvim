local M = {}

function M.get_list_branches()
	local handle = io.popen("git branch")
	local result = handle:read("*a")
	handle:close()
	return vim.split(result, "\n")
end

function M.get_current_branch()
	local handle = io.popen("git branch --show-current")
	local result = handle:read("*a")
	handle:close()
	return vim.split(result, "\n")
end

-- Function to get the staged diff
function M.get_staged_diff()
	local function run_command(cmd)
		local handle = io.popen(cmd)
		if handle then
			local result = handle:read("*a")
			handle:close()
			return result
		end
		return nil
	end

	-- Check if we're in a git repository
	local is_git_repo = run_command("git rev-parse --is-inside-work-tree 2>/dev/null")
	if not is_git_repo or is_git_repo:match("true") == nil then
		return nil, "Not in a git repository"
	end

	-- Get the staged diff
	local staged_diff = run_command("git diff --cached")
	if not staged_diff or staged_diff == "" then
		return nil, "No staged changes"
	end

	-- Get the list of staged files
	local staged_files = run_command("git diff --cached --name-only")
	if not staged_files or staged_files == "" then
		return nil, "Failed to get list of staged files"
	end

	return {
		diff = staged_diff,
		files = vim.split(staged_files, "\n"),
	}
end

function M.get_diff_between_branches(base_branch, branch)
	local function run_command(cmd)
		local handle = io.popen(cmd)
		if handle then
			local result = handle:read("*a")
			handle:close()
			return result
		end
		return nil
	end

	vim.notify("git diff " .. base_branch .. " " .. branch)
	local branch_diff = run_command("git diff " .. base_branch .. " " .. branch)

	if not branch_diff or branch_diff == "" then
		vim.notify("No diff between branches")
		return nil, "No diff between branches"
	end

	vim.notify(branch_diff)
end

return M
