:filetype off
:
set rtp+=~/.vim/bundle/vundle/
call vundle#rc()
" let Vundle manage Vundle:
Bundle 'laur/vundle'

" My Bundles
Bundle 'nerdtree'
Bundle 'vim-easymotion'
Bundle 'gundo'
Bundle 'nerdcommenter'
Bundle 'vim-surround'
Bundle 'command-t'
Bundle 'tagbar'
Bundle 'ctrlp.vim'
Bundle 'bufexplorer'

"let g:EasyMotion_leader_key = '<Leader>'

filetype plugin indent on

syntax on
set nocompatible

set modelines=0

set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab

set encoding=utf-8
set scrolloff=3
set autoindent
set smartindent
set showmode
set showcmd
set hidden
set wildmenu
set wildmode=list:longest
set visualbell
set cursorline
set ttyfast
set ruler
set backspace=indent,eol,start
set laststatus=2
set relativenumber
set undofile
" remove the old backup system vi used to do:
set nobackup
set noswapfile

let mapleader = ","

nnoremap / /\v
vnoremap / /\v
set ignorecase
set smartcase
set gdefault
set incsearch
set showmatch
set hlsearch
" clear the search buffer:
nmap <silent> ,/ :nohlsearch<CR>
nnoremap <leader><space> :noh<cr>
nnoremap <tab> %
vnoremap <tab> %

colorscheme mustang
set wrap
set textwidth=79
set formatoptions=qrn1
set colorcolumn=85

nnoremap <up> <nop>
nnoremap <down> <nop>
nnoremap <left> <nop>
nnoremap <right> <nop>
inoremap <up> <nop>
inoremap <down> <nop>
inoremap <left> <nop>
inoremap <right> <nop>
nnoremap j gj
nnoremap k gk

inoremap <F1> <ESC>
nnoremap <F1> <ESC>
vnoremap <F1> <ESC>

nnoremap ; :

au FocusLost * :wa

nnoremap <leader>ev <C-w><C-v><C-l>:e $MYVIMRC<cr>

nnoremap <leader>w <C-w>v<C-w>l

nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Go to the middle of the line
nmap gm :exe 'normal '.(virtcol('$')/2).'\\|'<CR>
" NERDtree toggle map:
map <C-n> :NERDTreeToggle<CR>
nnoremap <F5> :GundoToggle<CR>
"Powerline stuff:
set rtp+=/usr/local/lib/python2.7/dist-packages/powerline/bindings/vim/
" Always show statusline
set laststatus=2
"
" " Use 256 colours (Use this setting only if your terminal supports 256 colours)
set t_Co=256
" tagbar:
nmap <F8> :TagbarToggle<CR>
" map shift j&k to prev/next buffer:
map <S-J> :bp <CR>
map <S-K> :bn <CR>
" tab switching:
imap <A-1> <Esc>:tabn 1<CR>i
imap <A-2> <Esc>:tabn 2<CR>i
imap <A-3> <Esc>:tabn 3<CR>i
imap <A-4> <Esc>:tabn 4<CR>i
imap <A-5> <Esc>:tabn 5<CR>i
imap <A-6> <Esc>:tabn 6<CR>i
imap <A-7> <Esc>:tabn 7<CR>i
imap <A-8> <Esc>:tabn 8<CR>i
imap <A-9> <Esc>:tabn 9<CR>i

map <A-1> :tabn 1<CR>
map <A-2> :tabn 2<CR>
map <A-3> :tabn 3<CR>
map <A-4> :tabn 4<CR>
map <A-5> :tabn 5<CR>
map <A-6> :tabn 6<CR>
map <A-7> :tabn 7<CR>
map <A-8> :tabn 8<CR>
map <A-9> :tabn 9<CR>
nnoremap <C-S-t> :tabnew<CR>
inoremap <C-S-t> <Esc>:tabnew<CR>
"nnoremap <C-S-w> <Esc>:tabclose<CR>

nnoremap th  :tabfirst<CR>
nnoremap tj  :tabnext<CR>
nnoremap tk  :tabprev<CR>
nnoremap tl  :tablast<CR>
nnoremap tt  :tabedit<Space>
nnoremap tn  :tabnext<Space>
nnoremap tm  :tabm<Space>
nnoremap td  :tabclose<CR>
nnoremap <S-h> gT
nnoremap <S-l> gt

"map esc to double esc
"nnoremap <Esc> <Esc><Esc>
inoremap <Esc> <Esc><Esc>
vnoremap <Esc> <Esc><Esc>
" inoremap jj <ESC>

let g:ctrlp_cmd = 'CtrlPBuffer'
let g:ctrlp_regexp = 1
let g:ctrlp_switch_buffer = 'Et'

