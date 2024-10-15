local git = require("mai_pull_request.git")
local M = {}

-- Configuration table
M.config = {
	api_key = nil,
	create_commands = true,
	model = "gpt-4o-mini",
	max_tokens = 4096,
	temperature = 0.5,
  verbose_commit = false,
}

-- Function to set up the plugin configuration
function M.setup(opts)
  vim.api.nvim_set_keymap("n", "<leader>pr", ":MaiPR<CR>", { noremap = true, silent = true })
  vim.api.nvim_set_keymap("n", "<leader>vd", ":MaiDiffToCommit<CR>", { noremap = true, silent = true })

	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	if M.config.create_commands then
		M.create_commands()
	end
end

-- Function to create plugin commands
function M.create_commands()
	vim.api.nvim_create_user_command("MaiPR", function()
    require("mai_pull_request.diff-between-branches").show_branches()
	end, {})

	vim.api.nvim_create_user_command("MaiDiffToCommit", function()
		require("mai_pull_request.view_diff").view_diff()
	end, {})

	vim.api.nvim_create_user_command("MaiDiffBetweenBranches", function(opts)
		local base_branch = opts.fargs[1]
		local branch = opts.fargs[2]
		git.get_diff_between_branches(base_branch, branch)
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

return M
