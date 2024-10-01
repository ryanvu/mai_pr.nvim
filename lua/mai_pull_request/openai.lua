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
	local data = {
		model = model,
		messages = {
			{
				role = "system",
				content = "Generate a concise and informative git commit message based on the following code diff:",
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
	-- Similar to generate_commit_message, but tailored for PR descriptions
	-- Implement this function as needed
	local data = {
		model = model,
		messages = {
			{
				role = "system",
				content = "Generate a PR Template in Markdown based off of this diff:",
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

return M
