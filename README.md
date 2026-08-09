# nvim config

Single-file Neovim config (`init.lua`) targeting **Neovim >= 0.12**, built to be
self-bootstrapping: clone it, open `nvim`, and it installs everything it can by
itself. Works on macOS and WSL from the same file.

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

## What installs itself

Deliberately, no package manager is required for any of this:

| Component | Mechanism |
| --- | --- |
| lazy.nvim | Bootstrap clone at the top of `init.lua` |
| Plugins | lazy.nvim |
| LSP servers (`ts_ls`, `lua_ls`, `eslint`, `ruby_lsp`, `zls`) | `mason-lspconfig` → `ensure_installed` |
| `eslint_d`, `stylua` | `mason-tool-installer` → `ensure_installed` |
| `tree-sitter` CLI | `mason-tool-installer`; Mason ships it as a **prebuilt GitHub release binary**, so no `cargo`, `brew`, or `apt` is needed |
| Treesitter parsers | `require("nvim-treesitter").install(...)`, compiled locally |
| blink.cmp's Rust fuzzy matcher | Prebuilt binary fetched by blink because the plugin is pinned to a released tag (`version = "1.*"`); no `cargo` required. Confirm with `:checkhealth blink.cmp`. |
| `fzf` binary | `junegunn/fzf` plugin with `build = "./install --bin"`, which downloads a prebuilt per-arch tarball (no Go toolchain). Its `bin/` is prepended to `PATH` inside nvim only. If a compatible `fzf` is already on `PATH`, the script symlinks that instead of downloading. |

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
```

## Notes

- Diagnostics use `virtual_lines = { current_line = true }` (Neovim 0.11+)
  rather than the older `CursorHold` + `open_float` pattern.
- `[d` / `]d` are Neovim 0.11+ built-in defaults and are not remapped here.
  `vim.diagnostic.goto_prev` / `goto_next` are deprecated and removed in 0.13.
- Treesitter folding is available but not enabled. To turn it on:
  `vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"` and
  `vim.wo.foldmethod = "expr"`.
- Completion is blink.cmp with the `super-tab` preset: `<Tab>` accepts the
  selected item (or jumps forward in a snippet), `<CR>` also accepts, `<C-n>` /
  `<C-p>` cycle, `<C-e>` cancels, `<C-k>` toggles signature help. Snippets use
  Neovim's built-in `vim.snippet`, so there is no LuaSnip.
- LSP servers are configured with the native `vim.lsp.config()` /
  `vim.lsp.enable()` API. `mason-lspconfig` runs with
  `automatic_enable = false` so that `init.lua` stays the single source of
  truth for which servers are enabled.
