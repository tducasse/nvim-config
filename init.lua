-- Neovim config -- requires 0.12+. See README.md for setup and prerequisites.

-- ==================================================
-- Options
-- ==================================================
vim.g.mapleader = " " -- Must be set before lazy.nvim loads
vim.g.loaded_netrw = 1 -- Disable netrw before its startup plugins load
vim.g.loaded_netrwPlugin = 1

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
set.updatetime = 250 -- Also the CursorHold delay; raise if the float feels twitchy
set.autoread = true
set.scrolloff = 8
set.cursorline = true
set.undofile = true
set.foldmethod = "expr"
set.foldexpr = "v:lua.vim.treesitter.foldexpr()"
set.foldlevel = 99
set.foldlevelstart = 99 -- Keep files open; fold sections manually with za/zc

-- ==================================================
-- Diagnostics
-- ==================================================
-- Nothing inline: virtual_text truncates at the window edge and virtual_lines
-- pushes the buffer down. Signs and underlines mark the line; the full message
-- appears in a float, which costs no buffer space -- it matters for long TS errors.
vim.diagnostic.config({
	virtual_text = false,
	severity_sort = true,
})

vim.api.nvim_create_autocmd("CursorHold", {
	callback = function()
		-- Bail if any float is already open, so a hover (K) or signature popup
		-- is not clobbered while being read.
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			if vim.api.nvim_win_get_config(win).relative ~= "" then
				return
			end
		end
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

local function fzf(picker)
	return function()
		require("fzf-lua")[picker]()
	end
end

-- ==================================================
-- Plugins
-- ==================================================
require("lazy").setup({
	-- --------------------------------------------------
	-- Theme
	-- --------------------------------------------------
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

	-- --------------------------------------------------
	-- Treesitter
	-- --------------------------------------------------
	{
		-- The `main` branch is a full rewrite; `master` is locked and targets 0.11.
		-- main explicitly does not support lazy-loading, hence lazy = false.
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
				"json",
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

			-- Highlighting is not automatic on main; Neovim provides it and we opt in
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

			-- On a cold start Mason is still downloading tree-sitter-cli in the
			-- background, so installing parsers immediately would race it.
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

	-- --------------------------------------------------
	-- Finder & file explorer
	-- --------------------------------------------------
	{
		"ibhagwan/fzf-lua",
		lazy = false, -- Register vim.ui.select before the first code action
		dependencies = {
			"nvim-tree/nvim-web-devicons",
			-- Self-installing fzf binary: `install --bin` downloads a prebuilt
			-- per-arch tarball (no Go toolchain) and is a no-op once present.
			{ "junegunn/fzf", build = "./install --bin" },
		},
		config = function()
			-- lazy.nvim does not put plugin bin/ dirs on PATH
			local fzf_bin = vim.fn.stdpath("data") .. "/lazy/fzf/bin"
			if vim.fn.isdirectory(fzf_bin) == 1 then
				vim.env.PATH = fzf_bin .. ":" .. vim.env.PATH
			end
			require("fzf-lua").setup()
			require("fzf-lua").register_ui_select()
		end,
		keys = {
			{ "<leader>ff", fzf("files"), desc = "Find files" },
			{ "<leader>fg", fzf("live_grep"), desc = "Live grep" },
			{ "<leader>fw", fzf("grep_cword"), desc = "Grep word under cursor" },
			{ "<leader>fb", fzf("buffers"), desc = "Buffers" },
			{ "<leader>gs", fzf("git_status"), desc = "Git status" },
			{ "<leader>gl", fzf("git_commits"), desc = "Git log (repo)" },
			{ "<leader>gf", fzf("git_bcommits"), desc = "Git log (file)" },
			{ "<leader>gb", fzf("git_branches"), desc = "Git branches" },
		},
	},
	{
		"nvim-tree/nvim-tree.lua",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		keys = {
			{
				"<leader>e",
				function()
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
			require("nvim-tree").setup()
		end,
	},

	-- --------------------------------------------------
	-- Git
	-- --------------------------------------------------
	{
		-- Largely superseded by gitsigns/neogit/codediff, but kept for `:Git <any>`
		-- and 3-way conflict resolution (:Gdiffsplit! + :diffget //2 | //3), which
		-- nothing else here does. Lazy, so it costs no startup time.
		-- :GBrowse is omitted: it needs tpope/vim-rhubarb, which is not installed.
		"tpope/vim-fugitive",
		cmd = { "Git", "G", "Gdiffsplit", "Gread", "Gwrite", "Ggrep", "GMove", "GDelete" },
	},
	{
		"lewis6991/gitsigns.nvim",
		event = { "BufRead", "BufNewFile" },
		keys = {
			{ "]h", "<cmd>Gitsigns next_hunk<CR>", desc = "Next git hunk" },
			{ "[h", "<cmd>Gitsigns prev_hunk<CR>", desc = "Previous git hunk" },
			{ "<leader>hp", "<cmd>Gitsigns preview_hunk<CR>", desc = "Preview git hunk" },
			{ "<leader>hs", "<cmd>Gitsigns stage_hunk<CR>", desc = "Stage hunk" },
			{ "<leader>hr", "<cmd>Gitsigns reset_hunk<CR>", desc = "Reset hunk" },
			{ "<leader>hb", "<cmd>Gitsigns toggle_current_line_blame<CR>", desc = "Toggle git blame" },
		},
		opts = {
			current_line_blame = true, -- Toggle with <leader>hb
			current_line_blame_opts = { delay = 100 },
		},
	},
	{
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
		"NeogitOrg/neogit",
		dependencies = { "ibhagwan/fzf-lua", "esmuellert/codediff.nvim" },
		cmd = "Neogit",
		keys = {
			{ "<leader>gg", "<cmd>Neogit<CR>", desc = "Neogit status" },
			{ "<leader>gc", "<cmd>Neogit commit<CR>", desc = "Neogit commit" },
		},
		opts = {},
	},

	-- --------------------------------------------------
	-- Formatting
	-- --------------------------------------------------
	{
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		cmd = { "ConformInfo" },
		opts = {
			formatters_by_ft = {
				javascript = { "eslint_d" },
				javascriptreact = { "eslint_d" },
				typescript = { "eslint_d" },
				typescriptreact = { "eslint_d" },
				lua = { "stylua" },
			},
			-- format_on_save is synchronous on BufWritePre: one write. The
			-- format_after_save variant writes, formats, then writes again, which
			-- double-fires file watchers and HMR.
			format_on_save = {
				lsp_format = "fallback",
				timeout_ms = 2000,
			},
		},
	},

	-- --------------------------------------------------
	-- Completion
	-- --------------------------------------------------
	{
		-- Snippets use Neovim's built-in vim.snippet, so there is no LuaSnip.
		-- Pinned to 1.x: v2 is a breaking rewrite that also needs blink.lib, and
		-- only 1.x is tagged. A tagged version also means a prebuilt Rust fuzzy
		-- matcher is fetched, so cargo is not required.
		"saghen/blink.cmp",
		version = "1.*",
		event = "InsertEnter",
		opts = {
			keymap = {
				-- super-tab: Tab accepts when the menu is open, else jumps forward in
				-- a snippet, else falls through.
				preset = "super-tab",
				["<CR>"] = { "select_and_accept", "fallback" },
				-- Inverted on purpose, carried over from the old nvim-cmp mappings
				["<C-d>"] = { "scroll_documentation_up", "fallback" },
				["<C-u>"] = { "scroll_documentation_down", "fallback" },
			},
			sources = { default = { "lsp", "path", "snippets", "buffer" } },
			completion = {
				documentation = { auto_show = true, auto_show_delay_ms = 200 },
			},
			signature = { enabled = true },
			fuzzy = { implementation = "prefer_rust_with_warning" },
		},
	},

	-- --------------------------------------------------
	-- LSP
	-- --------------------------------------------------
	{
		-- Mason installs every external binary and prepends its bin/ to PATH.
		-- mason-lspconfig is deliberately absent: its remaining jobs were mapping
		-- lspconfig names to Mason package names and auto-enabling servers, both of
		-- which are done explicitly here. One list, named the way Mason names them.
		"mason-org/mason.nvim",
		dependencies = { "WhoIsSethDaniel/mason-tool-installer.nvim" },
		config = function()
			require("mason").setup()
			require("mason-tool-installer").setup({
				ensure_installed = {
					-- Servers
					"typescript-language-server",
					"lua-language-server",
					"eslint-lsp",
					"ruby-lsp",
					"zls",
					-- Formatters
					"eslint_d",
					"stylua",
					-- Required by nvim-treesitter; a prebuilt release binary, so this
					-- needs no cargo/brew/apt.
					"tree-sitter-cli",
				},
			})
		end,
	},
	{
		-- On 0.11+ this is effectively a data package: it ships the lsp/*.lua
		-- definitions (cmd, filetypes, root_markers) that Neovim auto-loads.
		-- Everything below uses the native vim.lsp API.
		"neovim/nvim-lspconfig",
		dependencies = { "mason-org/mason.nvim", "saghen/blink.cmp" },
		config = function()
			-- "*" applies to every server. The second arg folds in Neovim's own
			-- defaults, which cmp_nvim_lsp's default_capabilities() did not.
			vim.lsp.config("*", {
				capabilities = require("blink.cmp").get_lsp_capabilities(nil, true),
			})

			-- 0.11+ already provides grn (rename), gra (code action), grr
			-- (references), gri (implementation), grt (type definition), gO (document
			-- symbol), K (hover) and insert-mode <C-s> (signature). Override only
			-- where fzf-lua's picker wins.
			--
			-- Never map bare "gr": it prefixes the gr* defaults above, which makes
			-- every one of them wait for 'timeoutlen'.
			vim.api.nvim_create_autocmd("LspAttach", {
				callback = function(args)
					local opts = { buffer = args.buf }
					vim.keymap.set(
						"n",
						"gd",
						fzf("lsp_definitions"),
						vim.tbl_extend("force", opts, {
							desc = "Goto definition",
						})
					)
					vim.keymap.set(
						"n",
						"grr",
						fzf("lsp_references"),
						vim.tbl_extend("force", opts, {
							desc = "References",
						})
					)
				end,
			})

			vim.lsp.config("lua_ls", {
				settings = { Lua = { diagnostics = { globals = { "vim" } } } },
			})

			-- Diagnostics only; eslint_d does the formatting via conform
			vim.lsp.config("eslint", {
				settings = {
					format = false,
					workingDirectory = { mode = "auto" },
				},
			})

			vim.lsp.config("ruby_lsp", {
				flags = { debounce_text_changes = 150 },
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

			vim.lsp.enable({ "ts_ls", "lua_ls", "eslint", "ruby_lsp", "zls" })
		end,
	},

	-- --------------------------------------------------
	-- Editing & UI
	-- --------------------------------------------------
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
				theme = "auto",
				globalstatus = true,
				section_separators = "",
				component_separators = "",
			},
		},
	},

	-- --------------------------------------------------
	-- Claude Code
	-- --------------------------------------------------
	{
		"coder/claudecode.nvim",
		lazy = false, -- Starts the WebSocket server
		priority = 50,
		opts = {
			terminal = { provider = "none" }, -- Claude runs externally in tmux
		},
		config = function(_, opts)
			require("claudecode").setup(opts)
			vim.keymap.set("v", "<leader>cs", "<cmd>ClaudeCodeSend<CR>", { desc = "Send selection to Claude" })
			vim.keymap.set("n", "<leader>ca", "<cmd>ClaudeCodeAdd<CR>", { desc = "Add file to Claude context" })
		end,
	},
})

-- ==================================================
-- Keymaps
-- ==================================================
-- [d and ]d are 0.11+ defaults and are not redefined here.
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostics to loclist" })
