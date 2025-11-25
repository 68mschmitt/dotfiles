# Neovim Configuration

A modern, modular Neovim configuration focused on productivity and minimalism.

## Structure

```
.
├── init.lua                 # Entry point
├── lua/
│   ├── mike/               # Core configuration
│   │   ├── lazy.lua       # Plugin manager bootstrap
│   │   ├── options.lua    # Editor settings
│   │   ├── keymaps.lua    # Global keybindings
│   │   ├── autocmd.lua    # Autocommands and LSP setup
│   │   ├── statusline.lua # Custom statusline
│   │   └── utils.lua      # Utility functions
│   └── configs/            # Plugin configurations
│       ├── snacks/        # Snacks.nvim modules
│       ├── lsp.lua        # LSP and linting
│       ├── cmp.lua        # Completion engine
│       ├── treesitter.lua # Syntax highlighting
│       ├── git.lua        # Git integration
│       ├── dap.lua        # Debug adapter protocol
│       └── ...
├── snippets/              # Custom snippets
└── spell/                 # Spell check dictionaries
```

## Features

### Core Functionality
- **Plugin Management**: [lazy.nvim](https://github.com/folke/lazy.nvim) with lazy loading
- **LSP Support**: Full language server integration via `nvim-lspconfig` and Mason
- **Completion**: [blink.cmp](https://github.com/saghen/blink.cmp) with snippet support
- **Syntax**: Tree-sitter for advanced highlighting and text objects
- **Custom Statusline**: Minimal, handcrafted statusline with git and diagnostics

### Developer Tools
- **Git Integration**: Gitsigns for inline blame and status, Fugitive for git commands
- **Linting**: nvim-lint with biomejs (TypeScript) and write_good (Markdown)
- **Debugging**: DAP support with UI (currently disabled)
- **Snippets**: LuaSnip with friendly-snippets and custom snippets

### UI/UX
- **Theme**: Carbonfox (nightfox.nvim)
- **Picker**: Snacks.nvim picker for fuzzy finding
- **Dashboard**: Custom startup screen
- **File Explorer**: Snacks.nvim explorer
- **Notifications**: Snacks.nvim notifier

### Productivity
- **Inline Code Execution**: Execute Lua code directly in buffer
- **Smart Navigation**: Quick split navigation with `<C-hjkl>`
- **Buffer Management**: Tab/Shift-Tab for buffer cycling
- **Visual Line Movement**: Move lines up/down in visual mode

## Requirements

- Neovim >= 0.10
- Git
- Node.js (for some LSP servers)
- A Nerd Font (for icons)
- ripgrep (recommended for searching)

## Installation

```bash
# Clone this configuration
git clone <repo-url> ~/.config/nvim

# Start Neovim - plugins will auto-install
nvim
```

## Key Bindings

Leader key: `<Space>`

### General
| Key | Mode | Action |
|-----|------|--------|
| `<C-s>` | Normal | Save file |
| `<Esc>` | Normal | Clear search highlight + close quickfix |
| `<leader>nh` | Normal | Clear search highlight |
| `<Tab>` / `<S-Tab>` | Normal | Next/previous buffer |
| `<leader>cb` | Normal | Close buffer |

### Navigation
| Key | Mode | Action |
|-----|------|--------|
| `<C-hjkl>` | Normal | Navigate splits |
| `<C-A-hjkl>` | Normal | Resize splits |
| `n` / `N` | Normal | Search next/previous (centered) |
| `<A-n>` / `<A-p>` | Normal | Quickfix next/previous |

### Editing
| Key | Mode | Action |
|-----|------|--------|
| `J` / `K` | Visual | Move lines up/down |
| `J` | Normal | Join lines (cursor stays) |
| `<leader>p` | Visual | Paste without yanking |
| `<leader>d` | Normal/Visual | Delete to void register |
| `<leader>y` | Normal/Visual | Yank to system clipboard |

### LSP (when attached)
| Key | Mode | Action |
|-----|------|--------|
| `<leader>k` | Normal | Hover documentation |
| `gd` | Normal | Go to definition |
| `gD` | Normal | Go to declaration |
| `gi` | Normal | Go to implementation |
| `gr` | Normal | Find references |
| `<F2>` | Normal | Rename symbol |
| `<F3>` | Normal/Visual | Format |
| `<F4>` | Normal/Visual | Code actions |
| `<leader>dis` | Normal | Toggle diagnostics |

### Lua Execution
| Key | Mode | Action |
|-----|------|--------|
| `<leader><leader>x` | Normal | Source current file |
| `<leader>x` | Normal | Execute current line as Lua |
| `<leader>x` | Visual | Execute selection as Lua |

### Snacks.nvim Toggles
| Key | Action |
|-----|--------|
| `<leader>us` | Toggle spell check |
| `<leader>uw` | Toggle line wrap |
| `<leader>uL` | Toggle relative numbers |
| `<leader>ud` | Toggle diagnostics |
| `<leader>ul` | Toggle line numbers |
| `<leader>uc` | Toggle conceal level |
| `<leader>uT` | Toggle treesitter |
| `<leader>ub` | Toggle dark background |
| `<leader>uh` | Toggle inlay hints |

### Git
| Key | Mode | Action |
|-----|------|--------|
| `<leader>gs` | Normal | Git status (Fugitive) |

### Tabs
| Key | Action |
|-----|--------|
| `<leader>tn` | New tab |
| `<leader>te` | Close tab |
| `<leader>to` | Close other tabs |

### Spelling
| Key | Action |
|-----|--------|
| `z/` | Auto-correct to first suggestion |

## Editor Settings

- **Indentation**: 4 spaces, smart indent
- **Line Numbers**: Enabled with relative numbers
- **Scrolloff**: 8 lines
- **Search**: Incremental, case-insensitive, highlighted
- **Undo**: Persistent undo history
- **Splits**: Open right and below
- **No swap/backup files**
- **Update time**: 200ms
- **Timeout**: 300ms

## LSP Configuration

Mason is configured with custom registries for extended language support. LSP servers are automatically enabled via `mason-lspconfig`.

### Specialized LSP Features
- **Document Highlighting**: Automatically highlights symbol under cursor
- **Code Lens**: Refreshes on buffer enter and cursor hold
- **Lua Development**: Enhanced with lazydev.nvim and type definitions
- **JSON Schemas**: Integrated via schemastore.nvim

## Custom Features

### Statusline
Custom statusline showing:
- Current mode with highlighting
- File icon and name (with modified/readonly indicators)
- Git branch and changes
- LSP diagnostics
- Line/column and percentage
- OS icon

### Autocommands
- Highlight on yank
- Auto-detect JSX in `.js` files
- Enable spell check for markdown/text files
- Set `.vil` files as JSON
- C# compiler integration

## Optional Plugins

Several plugins are included but disabled by default (commented out in configs):

### AI/Copilot (`configs/copilot.lua`)
- `copilot.lua`: GitHub Copilot integration
- `avante.nvim`: AI-powered coding assistant
- `mcphub.nvim`: MCP protocol support
- `render-markdown.nvim`: Enhanced markdown rendering

### Debugging (`configs/dap.lua`)
- Full DAP setup with UI
- CoreCLR debugger for .NET

To enable, uncomment the relevant sections in the plugin configuration files.

## Development Plugin Path

Lazy.nvim is configured to look for local plugins in `~/projects/plugins/` before falling back to GitHub.

## Customization

Each plugin configuration is in its own file under `lua/configs/`. The structure is designed for easy modification:

1. **Add a plugin**: Create a new file in `lua/configs/`
2. **Modify keybindings**: Edit `lua/mike/keymaps.lua`
3. **Change options**: Edit `lua/mike/options.lua`
4. **Add autocommands**: Edit `lua/mike/autocmd.lua`

## License

Personal configuration - use as you wish.
