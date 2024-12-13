syntax on
filetype plugin indent on

set nocompatible

set path+=**

set hlsearch incsearch ignorecase smartcase
set number relativenumber
set encoding=UTF-8
set wildmenu
set wildoptions=pum
set wildmode=longest:full
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
autocmd Filetype yaml set cursorcolumn
autocmd Filetype yml set cursorcolumn

set splitbelow splitright

autocmd BufRead,BufNewFile * setlocal formatoptions-=cro

if $COLORTERM == 'truecolor'
	set termguicolors
endif

let mapleader="\<space>"

nnoremap <leader>nh :noh<CR>
nnoremap <leader>t :term<CR>

nnoremap <leader>s :setlocal spell!<CR>

nnoremap <leader>ff :find 

nnoremap <leader>fa :vimgrep  ./*<LEFT><LEFT><LEFT><LEFT>
