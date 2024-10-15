local config = require("mai_pull_request").config

local M = {}

local function get_api_key()
	return require("mai_pull_request").get_api_key()
end

local model, max_tokens, temperature = require("mai_pull_request").get_openai_config()

local function make_request(endpoint, data)
	local curl_command = string.format(
		"curl -s -X POST https://api.openai.com/v1/%s "
			.. "-H 'Content-Type: application/json' "
			.. "-H 'Authorization: Bearer %s' "
			.. "-d '%s'",
		endpoint,
		get_api_key(),
		vim.fn.json_encode(data):gsub("'", "'\\''")
	)

	local handle = io.popen(curl_command)
	local response = handle:read("*a")
	handle:close()

	return vim.fn.json_decode(response)
end

function M.generate_commit_message(diff)
	local system_message
	if config.verbose_commit then
		system_message =
			"Generate a detailed and informative git commit message based on the following code diff. Include a summary and key changes:"
	else
		system_message = "Generate a short, concise one-line git commit message based on the following code diff:"
	end

	local data = {
		model = model,
		messages = {
			{
				role = "system",
				content = system_message,
			},
			{ role = "user", content = diff },
		},
		max_tokens = max_tokens,
		temperature = temperature,
	}

	local response = make_request("chat/completions", data)

	if response and response.choices and response.choices[1] and response.choices[1].message then
		return response.choices[1].message.content
	else
		return "Failed to generate commit message"
	end
end

function M.generate_pr_description(diff)
	local data = {
		model = model,
		messages = {
			{
				role = "system",
				content = [[
                  Generate a concise and informative Pull Request Summary in Markdown based off of attached diff.
                  Refrain from including any code snippets in the PR description.
                ]],
			},
			{ role = "user", content = diff },
		},
		max_tokens = max_tokens,
		temperature = temperature,
	}

	local success, response = pcall(make_request, "chat/completions", data)

	if not success then
		print("Error making API request:", response)
		return "Failed to generate PR description: API request error"
	end

	if response and response.choices and response.choices[1] and response.choices[1].message then
		return response.choices[1].message.content
	else
		print("Unexpected API response structure:", vim.inspect(response))
		return "Failed to generate PR description: Unexpected API response"
	end
end

return M
