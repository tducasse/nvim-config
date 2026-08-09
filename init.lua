-- ==================================================
-- Leader Key (must be set before plugins)
-- ==================================================
vim.g.mapleader = " "

-- ==================================================
-- Basic Settings
-- ==================================================
local set = vim.opt
set.splitright = true
set.splitbelow = true
set.expandtab = true
set.tabstop = 2
set.shiftwidth = 2
set.ignorecase = true
set.smartcase = true
set.number = true
set.clipboard = "unnamedplus"
set.termguicolors = true
set.signcolumn = "yes"
set.updatetime = 250
set.autoread = true
set.scrolloff = 8
set.cursorline = true
set.undofile = true -- Persistent undo across sessions

-- Diagnostics: show the message inline on the cursor's line only (Nvim 0.11+),
-- replacing the old CursorHold + open_float pattern. virtual_text keeps it on a
-- single line so the buffer never shifts as the cursor moves; swap to
-- virtual_lines = { current_line = true } if you want full multi-line messages.
vim.diagnostic.config({
	virtual_text = { current_line = true }, -- Inline, cursor line only
	virtual_lines = false,
	signs = true, -- Keep gutter markers (E, W)
	underline = true, -- Keep underlines
	update_in_insert = false,
	severity_sort = true,
})

-- ==================================================
-- Bootstrap lazy.nvim
-- ==================================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

-- ==================================================
-- Plugin Setup
-- ==================================================
require("lazy").setup({
	-- ==================================================
	-- Theme
	-- ==================================================
	{
		"rebelot/kanagawa.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			require("kanagawa").setup({
				transparent = false,
				theme = "wave", -- "wave", "dragon", or "lotus"
			})
			vim.cmd.colorscheme("kanagawa")
		end,
	},
	-- ==================================================
	-- Treesitter (syntax, injections, textobjects)
	-- ==================================================
	{
		-- The `main` branch is a full rewrite; `master` is locked and targets 0.11.
		-- It explicitly does not support lazy-loading, hence lazy = false.
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false,
		build = ":TSUpdate",
		config = function()
			require("nvim-treesitter").setup()

			local parsers = {
				"bash",
				"css",
				"diff",
				"dockerfile",
				"gitcommit",
				"gitignore",
				"html",
				"javascript",
				"json", -- the jsonc filetype maps onto this parser
				"lua",
				"luadoc",
				"markdown",
				"markdown_inline",
				"python",
				"ruby",
				"toml",
				"tsx",
				"typescript",
				"vim",
				"vimdoc",
				"yaml",
				"zig",
			}

			-- Highlighting is not automatic on `main`; Neovim provides it and we opt in
			-- per buffer. Deriving the language from the filetype avoids maintaining a
			-- parallel filetype list.
			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("treesitter_start", { clear = true }),
				callback = function(args)
					local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
					if lang and pcall(vim.treesitter.language.add, lang) then
						pcall(vim.treesitter.start, args.buf, lang)
					end
				end,
			})

			local function install_parsers()
				if vim.fn.executable("tree-sitter") == 1 then
					require("nvim-treesitter").install(parsers)
					return true
				end
				return false
			end

			-- On a cold start, mason-tool-installer downloads tree-sitter-cli
			-- asynchronously and prepends Mason's bin to PATH, so installing parsers
			-- immediately would race it. Wait for Mason instead of failing.
			vim.api.nvim_create_autocmd("VimEnter", {
				once = true,
				callback = function()
					if install_parsers() then
						return
					end
					vim.api.nvim_create_autocmd("User", {
						pattern = "MasonToolsUpdateCompleted",
						once = true,
						callback = function()
							vim.schedule(function()
								if not install_parsers() then
									vim.notify(
										"nvim-treesitter: `tree-sitter` CLI not found.\n"
											.. "Run :MasonToolsInstall, then :TSUpdate.",
										vim.log.levels.WARN
									)
								end
							end)
						end,
					})
				end,
			})
		end,
	},
	-- ==================================================
	-- File Management
	-- ==================================================
	{
		"ibhagwan/fzf-lua",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
			-- Self-installing fzf binary. `install --bin` downloads a prebuilt
			-- per-arch tarball (no Go toolchain) and is a no-op once present, so
			-- fzf-lua works on a fresh machine without brew/apt.
			{
				"junegunn/fzf",
				build = "./install --bin",
			},
		},
		config = function()
			-- Prefer the plugin-local fzf binary; lazy.nvim does not add it to PATH.
			local fzf_bin = vim.fn.stdpath("data") .. "/lazy/fzf/bin"
			if vim.fn.isdirectory(fzf_bin) == 1 then
				vim.env.PATH = fzf_bin .. ":" .. vim.env.PATH
			end
			require("fzf-lua").setup()
			require("fzf-lua").register_ui_select()
		end,
		keys = {
			-- Function references rather than ":lua require(...)<CR>" strings: no
			-- command-line flash, and errors surface properly.
			{
				"<leader>ff",
				function()
					require("fzf-lua").files()
				end,
				desc = "Find files",
			},
			{
				"<leader>fg",
				function()
					require("fzf-lua").live_grep()
				end,
				desc = "Live grep",
			},
			{
				"<leader>fw",
				function()
					require("fzf-lua").grep_cword()
				end,
				desc = "Grep word under cursor",
			},
			{
				"<leader>fb",
				function()
					require("fzf-lua").buffers()
				end,
				desc = "Buffers",
			},
			{
				"<leader>gs",
				function()
					require("fzf-lua").git_status()
				end,
				desc = "Git status",
			},
			{
				"<leader>gl",
				function()
					require("fzf-lua").git_commits()
				end,
				desc = "Git log (repo)",
			},
			{
				"<leader>gf",
				function()
					require("fzf-lua").git_bcommits()
				end,
				desc = "Git log (file)",
			},
			{
				"<leader>gb",
				function()
					require("fzf-lua").git_branches()
				end,
				desc = "Git branches",
			},
		},
	},
	{
		"nvim-tree/nvim-tree.lua",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		keys = {
			{
				"<leader>e",
				function()
					-- If already in nvim-tree, close it. Otherwise, find/open file.
					if vim.bo.filetype == "NvimTree" then
						vim.cmd("NvimTreeClose")
					else
						vim.cmd("NvimTreeFindFile")
					end
				end,
				desc = "Toggle file explorer",
			},
		},
		config = function()
			vim.g.loaded_netrw = 1
			vim.g.loaded_netrwPlugin = 1
			require("nvim-tree").setup()
		end,
	},
	-- ==================================================
	-- Git
	-- ==================================================
	{
		"tpope/vim-fugitive",
		cmd = {
			"Git",
			"G",
			"Gdiffsplit",
			"Gread",
			"Gwrite",
			"Ggrep",
			"GMove",
			"GDelete",
			"GBrowse",
			"Git add",
			"Git commit",
			"Git push",
		},
	},
	{
		"lewis6991/gitsigns.nvim",
		event = { "BufRead", "BufNewFile" },
		keys = {
			{ "]h", ":Gitsigns next_hunk<CR>", desc = "Next git hunk" },
			{ "[h", ":Gitsigns prev_hunk<CR>", desc = "Previous git hunk" },
			{ "<leader>hp", ":Gitsigns preview_hunk<CR>", desc = "Preview git hunk" },
			{ "<leader>hs", ":Gitsigns stage_hunk<CR>", desc = "Stage hunk" },
			{ "<leader>hr", ":Gitsigns reset_hunk<CR>", desc = "Reset hunk" },
			{ "<leader>hb", ":Gitsigns toggle_current_line_blame<CR>", desc = "Toggle git blame" },
		},
		config = function()
			require("gitsigns").setup({
				current_line_blame = true, -- ON by default, toggle with <leader>hb
				current_line_blame_opts = {
					delay = 100,
				},
			})
		end,
	},
	{
		-- Replaces diffview.nvim, which had no commits for ~2 years. codediff is
		-- actively maintained and is the diff backend neogit now recommends.
		"esmuellert/codediff.nvim",
		cmd = { "CodeDiff" },
		keys = {
			{ "<leader>dv", "<cmd>CodeDiff<CR>", desc = "Diff vs HEAD" },
			{ "<leader>dh", "<cmd>CodeDiff history %<CR>", desc = "File history" },
			{ "<leader>dm", "<cmd>CodeDiff master<CR>", desc = "Diff vs master" },
			{ "<leader>ds", "<cmd>CodeDiff --staged<CR>", desc = "Diff staged" },
			{ "<leader>dc", "<cmd>tabclose<CR>", desc = "Close diff tab" },
		},
		opts = {},
	},
	{
		-- Magit-style staging/commit/branch UI. Pure Lua, no external binary
		-- (unlike lazygit), and no longer requires plenary.
		"NeogitOrg/neogit",
		dependencies = { "ibhagwan/fzf-lua", "esmuellert/codediff.nvim" },
		cmd = "Neogit",
		keys = {
			{ "<leader>gg", "<cmd>Neogit<CR>", desc = "Neogit status" },
			{ "<leader>gc", "<cmd>Neogit commit<CR>", desc = "Neogit commit" },
		},
		opts = {},
	},
	-- ==================================================
	-- Formatting
	-- ==================================================
	{
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		cmd = { "ConformInfo" },
		config = function()
			require("conform").setup({
				formatters_by_ft = {
					javascript = { "eslint_d" },
					javascriptreact = { "eslint_d" },
					typescript = { "eslint_d" },
					typescriptreact = { "eslint_d" },
					lua = { "stylua" },
				},
				format_after_save = {
					lsp_fallback = true,
				},
			})
		end,
	},
	-- ==================================================
	-- Autocompletion
	-- ==================================================
	{
		-- Replaces nvim-cmp + cmp-nvim-lsp/buffer/path + LuaSnip + cmp_luasnip.
		-- Snippets use Neovim's built-in vim.snippet, so LuaSnip is unnecessary.
		-- Pinned to 1.x: v2 is a breaking rewrite that additionally requires
		-- blink.lib, and only 1.x is tagged for release. The pinned tag also means
		-- lazy.nvim fetches a prebuilt Rust fuzzy matcher, so no cargo is needed.
		"saghen/blink.cmp",
		version = "1.*",
		event = "InsertEnter",
		opts = {
			-- 'super-tab' matches the previous behaviour: Tab accepts the selected
			-- item when the menu is open, otherwise jumps forward in a snippet,
			-- otherwise falls through to normal Tab.
			keymap = {
				preset = "super-tab",
				["<CR>"] = { "select_and_accept", "fallback" },
				-- Preserved verbatim from the nvim-cmp config, including the
				-- inverted feel: <C-d> scrolled docs up, <C-u> scrolled them down.
				["<C-d>"] = { "scroll_documentation_up", "fallback" },
				["<C-u>"] = { "scroll_documentation_down", "fallback" },
			},
			sources = {
				-- blink ranks a single merged list rather than using nvim-cmp's
				-- fallback groups.
				default = { "lsp", "path", "snippets", "buffer" },
			},
			completion = {
				-- Off by default in blink; nvim-cmp showed the docs window, so keep it.
				documentation = { auto_show = true, auto_show_delay_ms = 200 },
				-- accept.auto_brackets is already enabled by default: accepting a
				-- function inserts () and places the cursor inside.
			},
			-- Signature help while typing arguments; the old cmp setup had none.
			signature = { enabled = true },
			fuzzy = { implementation = "prefer_rust_with_warning" },
		},
	},
	-- ==================================================
	-- LSP (Language Server Protocol)
	-- ==================================================
	{
		-- Note: the mason projects moved from williamboman/* to mason-org/*.
		"mason-org/mason.nvim",
		config = function()
			require("mason").setup()
		end,
	},
	{
		"mason-org/mason-lspconfig.nvim",
		dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = { "ts_ls", "lua_ls", "eslint", "ruby_lsp", "zls" },
				-- mason-lspconfig 2.x auto-enables every Mason-installed server by
				-- default. We enable each one explicitly below (with settings), so
				-- turn that off to keep a single source of truth.
				automatic_enable = false,
			})
		end,
	},
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		dependencies = { "mason-org/mason.nvim" },
		config = function()
			require("mason-tool-installer").setup({
				ensure_installed = {
					"eslint_d",
					"stylua",
					-- Required by nvim-treesitter (main). Mason ships it as a prebuilt
					-- GitHub release binary, so this needs no cargo/brew/apt.
					"tree-sitter-cli",
				},
			})
		end,
	},
	{
		"neovim/nvim-lspconfig",
		dependencies = { "mason-org/mason-lspconfig.nvim", "saghen/blink.cmp" },
		config = function()
			-- The second arg folds in Neovim's own defaults, which cmp_nvim_lsp's
			-- default_capabilities() did not do.
			local capabilities = require("blink.cmp").get_lsp_capabilities(nil, true)

			-- Keybinds when LSP attaches
			vim.api.nvim_create_autocmd("LspAttach", {
				callback = function(args)
					local opts = { buffer = args.buf }
					vim.keymap.set("n", "gd", "<cmd>lua require('fzf-lua').lsp_definitions()<CR>", opts)
					vim.keymap.set("n", "gr", "<cmd>lua require('fzf-lua').lsp_references()<CR>", opts)
					vim.keymap.set("n", "gh", vim.lsp.buf.hover, opts)
					vim.keymap.set("n", "gf", "<cmd>lua require('fzf-lua').lsp_code_actions()<CR>", opts)
				end,
			})

			-- TypeScript/JavaScript
			vim.lsp.config("ts_ls", { capabilities = capabilities })
			vim.lsp.enable("ts_ls")

			-- Lua
			vim.lsp.config("lua_ls", {
				capabilities = capabilities,
				settings = {
					Lua = { diagnostics = { globals = { "vim" } } },
				},
			})
			vim.lsp.enable("lua_ls")

			-- ESLint (for real-time linting diagnostics)
			vim.lsp.config("eslint", {
				capabilities = capabilities,
				settings = {
					format = false,
					workingDirectory = { mode = "auto" },
				},
			})
			vim.lsp.enable("eslint")

			-- Ruby
			vim.lsp.config("ruby_lsp", {
				capabilities = capabilities,
				flags = {
					debounce_text_changes = 150,
				},
				init_options = {
					indexing = {
						excludedPatterns = {
							"**/app/react/**/*",
							"**/shared-packages/**/*",
							"**/e2e/**/*",
							"**/node_modules/**/*",
							"**/tmp/**/*",
							"**/log/**/*",
							"**/public/**/*",
							"**/vendor/bundle/**/*",
						},
					},
				},
			})
			vim.lsp.enable("ruby_lsp")

			-- Zig
			vim.lsp.config("zls", { capabilities = capabilities })
			vim.lsp.enable("zls")
		end,
	},
	-- ==================================================
	-- UI / Editing (all pure Lua, no external binaries)
	-- ==================================================
	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		opts = {},
		keys = {
			{
				"<leader>?",
				function()
					require("which-key").show({ global = false })
				end,
				desc = "Buffer-local keymaps",
			},
		},
	},
	{
		"kylechui/nvim-surround",
		version = "*",
		event = "VeryLazy",
		opts = {},
	},
	{
		"nvim-lualine/lualine.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		event = "VeryLazy",
		opts = {
			options = {
				theme = "auto", -- Picks up kanagawa automatically
				globalstatus = true,
				section_separators = "",
				component_separators = "",
			},
		},
	},
	-- ==================================================
	-- Claude Code IDE Integration
	-- ==================================================
	{
		"coder/claudecode.nvim",
		lazy = false, -- Load immediately to start WebSocket server
		priority = 50, -- Load early but after core plugins
		opts = {
			terminal = {
				provider = "none", -- No terminal management; run Claude externally in tmux
			},
		},
		config = function(_, opts)
			require("claudecode").setup(opts)
			-- Set up keymaps after plugin loads
			vim.keymap.set("v", "<leader>cs", ":ClaudeCodeSend<CR>", { desc = "Send selection to Claude" })
			vim.keymap.set("n", "<leader>ca", ":ClaudeCodeAdd<CR>", { desc = "Add file to Claude context" })
		end,
	},
})

-- ==================================================
-- Additional Keymaps
-- ==================================================
-- Note: [d and ]d are built-in default mappings in Nvim 0.11+, so they are not
-- redefined here. vim.diagnostic.goto_prev/goto_next are deprecated (removed in 0.13).
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostics to loclist" })
