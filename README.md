# Mai Pull Request

Mai Pull Request is a Neovim plugin that helps you create and manage pull requests directly from your Neovim editor.

## Features

- Create pull requests from within Neovim
- View diffs between branches
- Integrates with OpenAI for intelligent PR description generation

## Requirements

- Neovim >= 0.7.0
- Git (installed and configured in your system)
- OpenAI API key (for PR description generation)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

Add the following to your Neovim configuration:

```lua
{
  "yourusername/mai_pull_request",
  config = function()
    require("mai_pull_request").setup({
      -- your configuration here
    })
  end,
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
}
```

## Configuration

You can configure Mai Pull Request by passing options to the `setup` function:

```lua
require("mai_pull_request").setup({
  api_key = "your-openai-api-key", -- Set your OpenAI API key here
  create_commands = true, -- Set to false if you don't want to create commands
  model = "gpt-4o-mini", -- OpenAI model to use
  max_tokens = 4096, -- Maximum number of tokens for OpenAI requests
  temperature = 0.5, -- Temperature for OpenAI requests
})
```

## Usage

After installation and configuration, you can use the following commands:

- `:MaiPR`: Create a new pull request for the current branch
- `:MaiDiffToCommit`: View the diff for the current branch
- `:MaiDiffBetweenBranches <base_branch> <branch>`: View the diff between two branches

## Default Keymaps

The plugin sets up the following default keymaps:

- `<leader>pr`: Create a new pull request (equivalent to `:MaiPR`)
- `<leader>vd`: View diff to commit (equivalent to `:MaiDiffToCommit`)

You can customize these keymaps in your Neovim configuration if desired.

## Environment Variables

If you prefer not to store your OpenAI API key in your configuration, you can set it as an environment variable:

```sh
export OPEN_AI_API_KEY=your-api-key-here
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

If you encounter any problems or have any questions, please open an issue on the GitHub repository.
