# nvim config

Single-file Neovim config (`init.lua`) targeting **Neovim >= 0.12**, built to be
self-bootstrapping: clone it, open `nvim`, and it installs everything it can by
itself. Works on macOS and WSL from the same file.

Deliberately minimal, and native-first — LSP, diagnostics, keymaps and snippets
use built-in Neovim APIs wherever they exist rather than a plugin.

## Setup

### macOS

```sh
xcode-select --install                       # C compiler, git
git clone <this repo> ~/.config/nvim
nvim                                         # installs the rest itself
```

### WSL / Linux

```sh
sudo apt install build-essential git curl    # not present on a bare Ubuntu image
git clone <this repo> ~/.config/nvim
nvim                                         # installs the rest itself
```

Then install a [Nerd Font](https://www.nerdfonts.com/) — see [Fonts](#fonts).

First launch takes a few minutes: lazy.nvim clones plugins, Mason downloads
language servers, and Treesitter compiles parsers. Watch progress with `:Lazy`
and `:Mason`. It is safe to quit and reopen; everything is idempotent.

## What's in here

| Area | Plugin |
| --- | --- |
| Manager | lazy.nvim |
| Theme | kanagawa |
| Syntax | nvim-treesitter (`main` branch) |
| Find | fzf-lua (+ self-installing `fzf`) |
| Explorer | nvim-tree |
| Git | gitsigns, neogit, codediff, fugitive |
| Format | conform (`eslint_d`, `stylua`) |
| Complete | blink.cmp |
| LSP | nvim-lspconfig + mason, mason-tool-installer |
| Editing / UI | which-key, nvim-surround, lualine |
| AI | claudecode.nvim |

Servers: `ts_ls`, `lua_ls`, `eslint`, `ruby_lsp`, `zls`.

## Keymaps

Leader is `<Space>`. Press `<leader>` and pause for which-key, or `<leader>?` for
buffer-local maps.

### Find

| Key | Action |
| --- | --- |
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fw` | Grep word under cursor |
| `<leader>fb` | Buffers |
| `<leader>e` | Toggle file explorer |

### Git

| Key | Action |
| --- | --- |
| `<leader>gg` / `<leader>gc` | Neogit status / commit |
| `<leader>gs` | Git status (picker) |
| `<leader>gl` / `<leader>gf` | Git log, repo / current file |
| `<leader>gb` | Git branches |
| `]h` / `[h` | Next / previous hunk |
| `<leader>hp` | Preview hunk |
| `<leader>hs` / `<leader>hr` | Stage / reset hunk |
| `<leader>hb` | Toggle line blame (on by default) |

### Diff

| Key | Action |
| --- | --- |
| `<leader>dv` | Diff vs HEAD |
| `<leader>dm` | Diff vs `master` |
| `<leader>ds` | Diff staged |
| `<leader>dh` | File history |
| `<leader>dc` | Close diff tab |

### LSP

Most of these are **Neovim 0.11+ built-in defaults**, not config:

| Key | Action | Source |
| --- | --- | --- |
| `gd` | Goto definition (fzf-lua) | config |
| `grr` | References (fzf-lua) | config override |
| `grn` | Rename | built-in |
| `gra` | Code action (routed to fzf-lua via `ui.select`) | built-in |
| `gri` / `grt` | Implementation / type definition | built-in |
| `gO` | Document symbols | built-in |
| `K` | Hover | built-in |
| `<C-s>` (insert) | Signature help | built-in |
| `[d` / `]d` | Previous / next diagnostic | built-in |
| `<C-w>d` | Diagnostic float on demand | built-in |
| `<leader>q` | Diagnostics to loclist | config |

> Never map bare `gr` — it prefixes the `gr*` defaults above, which makes every
> one of them wait for `timeoutlen`.

### Completion (blink.cmp, `super-tab` preset)

| Key | Action |
| --- | --- |
| `<Tab>` | Accept selected item, else jump forward in snippet |
| `<CR>` | Accept |
| `<C-n>` / `<C-p>` | Next / previous item |
| `<C-e>` | Cancel |
| `<C-k>` | Toggle signature help |
| `<C-d>` / `<C-u>` | Scroll docs up / down (inverted on purpose) |

### Other

| Key | Action |
| --- | --- |
| `<leader>cs` (visual) | Send selection to Claude |
| `<leader>ca` | Add file to Claude context |
| `ys` / `cs` / `ds` | Surround add / change / delete |

## What installs itself

Deliberately, no package manager is required for any of this:

| Component | Mechanism |
| --- | --- |
| lazy.nvim | Bootstrap clone at the top of `init.lua` |
| Plugins | lazy.nvim |
| LSP servers, `eslint_d`, `stylua` | `mason-tool-installer` → `ensure_installed`, by Mason package name |
| `tree-sitter` CLI | `mason-tool-installer`; Mason ships it as a **prebuilt GitHub release binary**, so no `cargo`, `brew`, or `apt` is needed |
| Treesitter parsers | `require("nvim-treesitter").install(...)`, compiled locally |
| blink.cmp's Rust fuzzy matcher | Prebuilt binary fetched by blink because the plugin is pinned to a released tag (`version = "1.*"`); no `cargo` required. Confirm with `:checkhealth blink.cmp`. |
| `fzf` binary | `junegunn/fzf` with `build = "./install --bin"`, which downloads a prebuilt per-arch tarball (no Go toolchain). Its `bin/` is prepended to `PATH` inside nvim only. If a compatible `fzf` is already on `PATH`, the script symlinks that instead of downloading. |

### Bootstrap ordering

`nvim-treesitter` (`main` branch) cannot be lazy-loaded, so on a cold start it
would otherwise race `mason-tool-installer`, which is still downloading the
`tree-sitter` CLI in the background. The config therefore attempts the parser
install on `VimEnter` and, if the CLI is not yet on `PATH`, waits for Mason's
`MasonToolsUpdateCompleted` event before retrying. If it still is not found you
get a warning telling you to run `:MasonToolsInstall` then `:TSUpdate` — never a
stacktrace.

## Prerequisites that cannot be automated

| Prereq | macOS | WSL / Linux | Needed for |
| --- | --- | --- | --- |
| C compiler | Xcode Command Line Tools | `build-essential` | Compiling Treesitter parsers |
| `git`, `curl`, `tar` | preinstalled | `git curl` via apt | lazy.nvim, Mason, parser downloads |
| Nerd Font | see below | see below | Icons in fzf-lua, nvim-tree, lualine |
| `node` / `npm` | [fnm](https://github.com/Schniz/fnm) | fnm | `ts_ls`, `eslint`, `eslint_d` |
| `ruby` / `gem` | rvm / rbenv | rvm / rbenv | `ruby_lsp` |

`node` and `ruby` are managed per-project by version managers, so they are
intentionally left out of any bootstrap script.

### Fonts

Icons need a Nerd Font selected **in the terminal emulator**, which no
in-editor mechanism can do for you.

- **macOS**: `brew install --cask font-jetbrains-mono-nerd-font`, then set it in
  your terminal profile.
- **WSL**: install the font **on the Windows host**, not inside WSL, and set it
  in Windows Terminal (Settings → Profile → Appearance → Font face). A Brewfile
  cannot do this: font casks are macOS-only, and the font is a Windows setting.

## WSL notes

- **Clipboard.** `clipboard = "unnamedplus"` relies on Neovim's WSL clipboard
  provider. For paste to work reliably you need
  [`win32yank.exe`](https://github.com/equalsraf/win32yank) on `PATH`; `clip.exe`
  alone only covers copy. Verify with `:checkhealth provider`.
- Treesitter parsers are compiled inside WSL, so `build-essential` is required
  and cannot be skipped.

## Troubleshooting

### `ruby-lsp` fails to install with a zlib `LoadError`

If Mason reports `gem failed with exit code 1` and the log contains
`Library not loaded: /opt/homebrew/opt/zlib/lib/libz.1.dylib`, the Ruby
install is broken, not the config — rvm compiled Ruby against Homebrew's
keg-only zlib and that formula was later removed (`brew autoremove` will do
this, because zlib is usually present only as someone else's dependency).
Confirm with:

```sh
ruby -rzlib -e 'puts Zlib::VERSION'   # raises LoadError when broken
```

Fix by reinstalling it explicitly, which also marks it as
installed-on-request so `brew autoremove` leaves it alone in future:

```sh
brew install zlib
```

This breaks every gem operation, not just Mason.

### `ruby_lsp` exits with code 78

`Project contains a Gemfile, but no Gemfile.lock` — run `bundle install` in
the project and restart. Not a config problem.

## Health check

```vim
:checkhealth
:Lazy
:Mason
:ConformInfo
:checkhealth blink.cmp
```

## Design notes

- **Diagnostics** show nothing inline. Signs and underlines mark the line, and
  the full message appears in a float on `CursorHold` (`updatetime` controls the
  delay). `virtual_text` truncates at the window edge and `virtual_lines` pushes
  the buffer down; a float costs no buffer space, which matters for long
  TypeScript errors. The autocmd bails if another float is already open so a
  hover is not clobbered.
- **LSP** is configured with the native `vim.lsp.config()` / `vim.lsp.enable()`
  API. A single `vim.lsp.config("*", ...)` supplies capabilities to every
  server. `nvim-lspconfig` is kept only for its `lsp/*.lua` data (cmd,
  filetypes, root markers).
- **`mason-lspconfig` is deliberately absent.** Its remaining jobs were mapping
  lspconfig names to Mason package names and auto-enabling servers, both of
  which `init.lua` does explicitly. One list, named the way Mason names them.
- **`fugitive` is kept despite heavy overlap** with gitsigns/neogit/codediff,
  for `:Git <anything>` and 3-way conflict resolution (`:Gdiffsplit!` then
  `:diffget //2` / `//3`). It is lazy, so it costs no startup time. `:GBrowse`
  is *not* wired up — it requires `tpope/vim-rhubarb`.
- **`conform` uses `format_on_save`**, which is synchronous on `BufWritePre` and
  writes once. The `format_after_save` variant writes, formats, then writes
  again, double-firing file watchers and HMR.
- **Treesitter folding** is available but not enabled. To turn it on:
  `vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"` and
  `vim.wo.foldmethod = "expr"`.
- **Single file on purpose.** At ~500 lines with 13 plugins, splitting into
  `lua/plugins/*.lua` would mean more files than concepts and would hide the
  load-order constraints in the Treesitter and Mason blocks. Revisit if any
  section passes ~150 lines, or if platform-specific plugin sets are needed.
