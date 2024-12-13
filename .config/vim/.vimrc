syntax on
filetype plugin indent on

set nocompatible

set path+=**

set hlsearch incsearch smartcase
set number relativenumber
set encoding=UTF-8
set wildmenu
set wildoptions=pum
set wildmode=longest:full
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab

"Vertical line to help with formatting in yaml files"
autocmd Filetype yaml set cursorcolumn
autocmd Filetype yml set cursorcolumn

"Does something with window splits"
set splitbelow splitright

"Prevents auto comments when creating new lines"
autocmd BufRead,BufNewFile * setlocal formatoptions-=cro

"Enable colors in vim"
if $COLORTERM == 'truecolor'
	set termguicolors
endif

let mapleader="\<space>"

"Turn off highlighting when in the search results view"
nnoremap <leader>nh :noh<CR>

"Open a terminal"
nnoremap <leader>t :term<CR>

"Toggle spell check"
nnoremap <leader>s :setlocal spell!<CR>

"Find file, accepts a regular expression"
nnoremap <leader>ff :find 

"Search through all files"
nnoremap <leader>fa :vimgrep  ./*<LEFT><LEFT><LEFT><LEFT>

"Controls to manage buffers, starting with the leader key, then 'b' for buffer then n-ext p-revious d-elete and bb to list all because its easy"
nnoremap <leader>bn :bnext<CR>
nnoremap <leader>bp :bprevious<CR>
nnoremap <leader>bd :bdelete<CR>
nnoremap <leader>bb :ls<CR>
