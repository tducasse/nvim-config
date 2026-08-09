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

-- Diagnostics: nothing inline. Signs and underlines give the ambient "something
-- is wrong here" signal, and the full message appears in a float on CursorHold.
-- Unlike virtual_text (truncates at the window edge) and virtual_lines (pushes
-- the buffer down), a float costs no buffer space and shows every diagnostic on
-- the line, which matters for long TypeScript errors.
vim.diagnostic.config({
	virtual_text = false,
	virtual_lines = false,
	signs = true, -- Keep gutter markers (E, W)
	underline = true, -- Keep underlines
	update_in_insert = false,
	severity_sort = true,
})

-- Show the diagnostic float when the cursor rests ('updatetime' controls the
-- delay; raise it if this feels twitchy). <C-w>d is the built-in on-demand
-- equivalent if you ever want to drop the automatic behaviour.
vim.api.nvim_create_autocmd("CursorHold", {
	callback = function()
		-- Never stack on top of an existing float, so a hover (K) or signature
		-- popup does not get clobbered while you are reading it.
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
				-- format_on_save runs on BufWritePre, synchronously: one write.
				-- format_after_save runs on BufWritePost asynchronously, which writes
				-- the file, formats, then writes again -- double file-watcher and HMR
				-- events for anything watching the tree.
				format_on_save = {
					lsp_format = "fallback", -- The modern spelling of lsp_fallback = true
					timeout_ms = 2000,
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
		-- Mason installs every external binary into stdpath("data")/mason/bin and
		-- prepends that to PATH. Note: the mason projects moved to mason-org/*.
		--
		-- mason-lspconfig is deliberately not used. Its only remaining jobs were
		-- translating lspconfig server names into Mason package names, and
		-- auto-enabling installed servers, which we already do explicitly. Naming
		-- packages directly keeps every tool in one declarative list.
		"mason-org/mason.nvim",
		dependencies = { "WhoIsSethDaniel/mason-tool-installer.nvim" },
		config = function()
			require("mason").setup()
			require("mason-tool-installer").setup({
				ensure_installed = {
					-- LSP servers (Mason package names, not lspconfig names)
					"typescript-language-server",
					"lua-language-server",
					"eslint-lsp",
					"ruby-lsp",
					"zls",
					-- Formatters
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
		-- On 0.11+ this plugin is essentially a data package: it ships lsp/*.lua
		-- definitions (cmd, filetypes, root_markers) that Neovim auto-loads from
		-- the runtimepath. Configuration below uses the native vim.lsp API.
		"neovim/nvim-lspconfig",
		dependencies = { "mason-org/mason.nvim", "saghen/blink.cmp" },
		config = function()
			-- "*" applies to every server, replacing the per-server repetition.
			-- The second arg folds in Neovim's own defaults, which cmp_nvim_lsp's
			-- default_capabilities() did not do.
			vim.lsp.config("*", {
				capabilities = require("blink.cmp").get_lsp_capabilities(nil, true),
			})

			-- Neovim 0.11+ already provides grn (rename), gra (code action),
			-- grr (references), gri (implementation), grt (type definition),
			-- gO (document symbol), K (hover) and insert-mode <C-s> (signature).
			-- Only override where fzf-lua's picker is a genuine upgrade.
			--
			-- Do NOT map bare "gr": it is the prefix of the gr* defaults above, so
			-- mapping it makes all of them wait for 'timeoutlen' before resolving.
			vim.api.nvim_create_autocmd("LspAttach", {
				callback = function(args)
					local opts = { buffer = args.buf }
					vim.keymap.set("n", "gd", function()
						require("fzf-lua").lsp_definitions()
					end, vim.tbl_extend("force", opts, { desc = "Goto definition" }))
					vim.keymap.set("n", "grr", function()
						require("fzf-lua").lsp_references()
					end, vim.tbl_extend("force", opts, { desc = "References" }))
				end,
			})

			-- Lua
			vim.lsp.config("lua_ls", {
				settings = {
					Lua = { diagnostics = { globals = { "vim" } } },
				},
			})

			-- ESLint (real-time linting diagnostics; formatting is done by eslint_d
			-- via conform, so the server's own formatter is disabled)
			vim.lsp.config("eslint", {
				settings = {
					format = false,
					workingDirectory = { mode = "auto" },
				},
			})

			-- Ruby
			vim.lsp.config("ruby_lsp", {
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

			-- ts_ls and zls need no extra settings beyond the "*" defaults.
			vim.lsp.enable({ "ts_ls", "lua_ls", "eslint", "ruby_lsp", "zls" })
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
