-- ==================================================
-- Leader Key (must be set before plugins)
-- ==================================================
vim.g.mapleader = " "

-- ==================================================
-- Basic Settings
-- ==================================================
local set = vim.opt
set.lazyredraw = true
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

-- Show diagnostics on hover only (cleaner)
vim.diagnostic.config({
	virtual_text = false, -- No inline text
	signs = true, -- Keep gutter markers (E, W)
	underline = true, -- Keep underlines
	update_in_insert = false,
	severity_sort = true,
})

-- Show diagnostic popup on hover
vim.api.nvim_create_autocmd("CursorHold", {
	callback = function()
		vim.diagnostic.open_float(nil, { focusable = false })
	end,
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
	-- File Management
	-- ==================================================
	{
		"ibhagwan/fzf-lua",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
		},
		config = function()
			require("fzf-lua").setup()
			require("fzf-lua").register_ui_select()
		end,
		keys = {
			{ "<leader>ff", ":lua require('fzf-lua').files()<CR>" },
			{ "<leader>fg", ":lua require('fzf-lua').live_grep()<CR>" },
			{ "<leader>fw", ":lua require('fzf-lua').grep_cword()<CR>", desc = "Grep word under cursor" },
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
		"sindrets/diffview.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
		keys = {
			{ "<leader>dv", ":DiffviewOpen<CR>", desc = "Diff vs HEAD" },
			{ "<leader>dh", ":DiffviewFileHistory %<CR>", desc = "File history" },
			{ "<leader>dm", ":DiffviewOpen master<CR>", desc = "Diff vs master" },
			{ "<leader>dc", ":DiffviewClose<CR>", desc = "Close diffview" },
			{ "<leader>dr", ":DiffviewRefresh<CR>", desc = "Refresh diffview" },
		},
		config = function()
			require("diffview").setup()
			-- Auto-refresh when in diffview (to watch changes live)
			vim.api.nvim_create_autocmd({ "FocusGained", "CursorHold", "CursorMoved", "BufEnter" }, {
				pattern = "diffview://*",
				callback = function()
					vim.cmd("silent! checktime")
					vim.cmd("silent! DiffviewRefresh")
				end,
			})
		end,
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
		"hrsh7th/nvim-cmp",
		event = "InsertEnter",
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-path",
			"L3MON4D3/LuaSnip",
			"saadparwaiz1/cmp_luasnip",
		},
		config = function()
			local cmp = require("cmp")
			local luasnip = require("luasnip")

			cmp.setup({
				snippet = {
					expand = function(args)
						luasnip.lsp_expand(args.body)
					end,
				},
				mapping = cmp.mapping.preset.insert({
					["<C-n>"] = cmp.mapping.select_next_item(),
					["<C-p>"] = cmp.mapping.select_prev_item(),
					["<C-d>"] = cmp.mapping.scroll_docs(-4),
					["<C-u>"] = cmp.mapping.scroll_docs(4),
					["<C-Space>"] = cmp.mapping.complete(),
					["<C-e>"] = cmp.mapping.abort(),
					["<CR>"] = cmp.mapping.confirm({ select = true }),
					["<Tab>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							cmp.confirm({ select = true })
						elseif luasnip.expand_or_jumpable() then
							luasnip.expand_or_jump()
						else
							fallback()
						end
					end, { "i", "s" }),
					["<S-Tab>"] = cmp.mapping(function(fallback)
						if luasnip.jumpable(-1) then
							luasnip.jump(-1)
						else
							fallback()
						end
					end, { "i", "s" }),
				}),
				sources = cmp.config.sources({
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
				}, {
					{ name = "buffer" },
					{ name = "path" },
				}),
			})
		end,
	},
	-- ==================================================
	-- LSP (Language Server Protocol)
	-- ==================================================
	{
		"williamboman/mason.nvim",
		config = function()
			require("mason").setup()
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = { "ts_ls", "lua_ls", "eslint", "ruby_lsp" },
			})
		end,
	},
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			require("mason-tool-installer").setup({
				ensure_installed = {
					"eslint_d",
					"stylua",
				},
			})
		end,
	},
	{
		"neovim/nvim-lspconfig",
		dependencies = { "williamboman/mason-lspconfig.nvim", "hrsh7th/cmp-nvim-lsp" },
		config = function()
			local capabilities = require("cmp_nvim_lsp").default_capabilities()

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
		end,
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
-- Diagnostic navigation
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostics to loclist" })
