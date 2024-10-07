local M = {}

-- Configuration table
M.config = {
	api_key = nil,
	create_commands = true,
	model = "gpt-4o-mini",
	max_tokens = 4096,
	temperature = 0.5,
	-- You can add other configuration options here
}

-- Function to set up the plugin configuration
function M.setup(opts)
  vim.api.nvim_set_keymap("n", "<leader>pr", ":MaiGetAPIKey<CR>", { noremap = true, silent = true })
  vim.api.nvim_set_keymap("n", "<leader>vd", ":MaiDiffToCommit<CR>", { noremap = true, silent = true })

	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	if M.config.create_commands then
		M.create_commands()
	end
end

-- Function to create plugin commands
function M.create_commands()
	vim.api.nvim_create_user_command("MaiGetAPIKey", function()
    require("mai_pull_request.diff-between-branches").show_branches()
	end, {})

	vim.api.nvim_create_user_command("MaiDiffToCommit", function()
		require("mai_pull_request.view_diff").view_diff()
	end, {})

	vim.api.nvim_create_user_command("MaiPRWindow", function()
		require("mai_pull_request.ui").create_complex_float()
	end, {})

	vim.api.nvim_create_user_command("MaiDiffBetweenBranches", function(opts)
		local base_branch = opts.fargs[1]
		local branch = opts.fargs[2]
		M.get_diff_between_branches(base_branch, branch)
	end, { nargs = "+" })
end

-- Function to get the OpenAI API Key
function M.get_api_key()
	if M.config.api_key then
		return M.config.api_key
	end

	-- Check for environment variable
	local env_api_key = vim.fn.getenv("OPEN_AI_API_KEY")
	if env_api_key and env_api_key ~= "" then
		return env_api_key
	end

	-- If no API key is found, throw an error
	error(
		"OpenAI API key not found. Please set it in your configuration or as an environment variable (OPEN_AI_API_KEY)."
	)
end

function M.get_openai_config()
	local model = M.config.model
	local max_tokens = M.config.max_tokens
	local temperature = M.config.temperature
	return model, max_tokens, temperature
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
