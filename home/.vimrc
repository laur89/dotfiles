
" We use Vim settings
set nocompatible " Must be the first line

""" Vundle plugin manager {{{
    """ Automatically setting up Vundle, taken from
    """ http://www.erikzaadi.com/2012/03/19/auto-installing-vundle-from-your-vimrc/ {{{
        let has_vundle=1
        if !filereadable($HOME."/.vim/bundle/Vundle.vim/README.md")
            echo "Installing Vundle..."
            echo ""
            silent !mkdir -p $HOME/.vim/bundle
            silent !git clone https://github.com/gmarik/Vundle.vim $HOME/.vim/bundle/Vundle.vim
            let has_vundle=0
        endif
    """ }}}
    
    """ Initialize Vundle {{{
        filetype off                                " required to init
        set rtp+=$HOME/.vim/bundle/Vundle.vim       " include vundle
        call vundle#begin()                         " init vundle
    """ }}}
    
    """ Github repos, uncomment to disable a plugin {{{
    Plugin 'gmarik/Vundle.vim'

    """ Local plugins (and only plugins in this file!) {{{{
        if filereadable($HOME."/.vimrc.plugins")
            source $HOME/.vimrc.plugins
        endif
    """ }}}

    " Edit files using sudo/su
    "Plugin 'chrisbra/SudoEdit.vim'

    " <Tab> everything!
    "Plugin 'ervandew/supertab'

    " Fuzzy finder (files, mru, etc)
    Plugin 'kien/ctrlp.vim'

    " A pretty statusline, bufferline integration
    "Plugin 'itchyny/lightline.vim' " liiga minimalist mu jaoks
    Plugin 'bling/vim-airline'
    Plugin 'bling/vim-bufferline'

    " Easy... motions... yeah.
    Plugin 'Lokaltog/vim-easymotion'

    " Glorious colorscheme
    "Plugin 'nanotech/jellybeans.vim'

    " Super easy commenting, toggle comments etc
    Plugin 'scrooloose/nerdcommenter'

    " Autoclose (, " etc; ie when you insert an (, then ) will be automatically
    " inserted, and cursor placed between them;
    Plugin 'Townk/vim-autoclose'

    " Git wrapper inside Vim
    Plugin 'tpope/vim-fugitive'

    " Handle surround chars like ''
    Plugin 'tpope/vim-surround'

    " Align your = etc.
    Plugin 'vim-scripts/Align'

    " Snippets like textmate
    Plugin 'MarcWeber/vim-addon-mw-utils' "vim-snipmate depends on this one
    Plugin 'tomtom/tlib_vim'              " ... and this.
    Plugin 'honza/vim-snippets'           " The snippets repo, and...
    Plugin 'sirver/ultisnips'             "...the engine.

    " A fancy start screen, shows MRU etc.
    Plugin 'mhinz/vim-startify'

    " Vim signs (:h signs) for modified lines based off VCS (e.g. Git)
    Plugin 'mhinz/vim-signify'

    " Awesome syntax checker.
    " REQUIREMENTS: See :h syntastic-intro
    Plugin 'scrooloose/syntastic'

    " Functions, class data etc.
    " REQUIREMENTS: (exuberant)-ctags
    Plugin 'majutsushi/tagbar'
    
    " Selfexplanatory...
    Plugin 'jlanzarotta/bufexplorer'
    
    " File browser
    Plugin 'scrooloose/nerdtree'
    
    " Visualise the undo tree
    Plugin 'sjl/gundo.vim'
    
    " fast mechanism to open files and buffers
    Plugin 'wincent/Command-T'

    " development completion engine (integrates with utilsnips and deprecates
    " supertab et al; needs compilation! read the docs!:
    " !!! ühed väidavad, et javaphp,js,html jaoks on neocomplete parem;
    Plugin 'Valloric/YouCompleteMe'

    " Finish Vundle stuff
    call vundle#end()

    """ Installing plugins the first time, quits when done {{{
        if has_vundle == 0
            :silent! PluginInstall
            :qa
        endif
    """ }}}
""" }}}

""" Local leading config, only use for prerequisites as it will be
""" overwritten by anything below {{{
    if filereadable($HOME."/.vimrc.first")
        source $HOME/.vimrc.first
    endif
""" }}}

""" User interface {{{
    """ Syntax highlighting {{{
        filetype plugin indent on                   " load filetype plugins and indent settings
        syntax on                                   " syntax highlighting
        set background=dark                         " we're using a dark bg
        colors mustang                           " select colorscheme
        au BufNewFile,BufRead *.txt se ft=sh tw=79  " opens .txt w/highlight
        au BufNewFile,BufRead *.tex se ft=tex tw=79 " we don't want plaintex
        au BufNewFile,BufRead *.md se ft=markdown tw=79 " markdown, not modula
        
        """ 256 colors for maximum jellybeans bling. See commit log for info {{{
            "if (&term =~ "xterm") || (&term =~ "screen")
            "    set t_Co=256
            "endif
        " Use 256 colours (Use this setting only if your terminal supports 256 colours)
        " (currently overrides the above if-block)
        set t_Co=256
        """ }}}
        
        """ Tab colors, overwritten by lightline(?) {{{
            "hi TabLineFill ctermfg=NONE ctermbg=233
            "hi TabLine ctermfg=241 ctermbg=233
            "hi TabLineSel ctermfg=250 ctermbg=233
        """ }}}
        
        """ Custom highlighting, where NONE uses terminal background {{{
            function! CustomHighlighting()
                highlight Normal ctermbg=NONE
                highlight nonText ctermbg=NONE
                highlight LineNr ctermbg=NONE
                highlight SignColumn ctermbg=NONE
                highlight CursorLine ctermbg=235
            endfunction

            call CustomHighlighting()
        """ }}}
    """ }}}
    
    """ Interface general {{{
        set cursorline                              " hilight cursor line
        set more                                    " ---more--- like less
        set number                                  " line numbers
        set scrolloff=3                             " lines above/below cursor
        set showcmd                                 " show cmds being typed
        set title                                   " window title
        set vb t_vb=                                " disable beep and flashing
        set wildignore=.bak,.pyc,.o,.ojb,.a,
                       \.pdf,.jpg,.gif,.png,
                       \.avi,.mkv,.so               " ignore said files
        set wildmenu                                " better auto complete
        set wildmode=longest,list                   " bash-like auto complete
        
        """ Encoding {{{
            " If you're having problems with some characters you can force
            " UTF-8 if your locale is something else.
            " WARNING: this will affect encoding used when editing files!
            "
            " set encoding=utf-8                    " for character glyphs
        """ }}}
        
        """ Gvim {{{
            set guifont=DejaVu\ Sans\ Mono\ 9
            set guioptions-=m                       " remove menubar
            set guioptions-=T                       " remove toolbar
            set guioptions-=r                       " remove right scrollbar
        """ }}}
    """ }}}
""" }}}

""" General settings {{{
    set hidden                                      " buffer change, more undo
    set history=1000                                " default 20
    set iskeyword+=_,$,@,%,#                        " not word dividers
    set laststatus=2                                " always show statusline
    set linebreak                                   " don't cut words on wrap
    set listchars=tab:>\                            " > to highlight <tab>
    set list                                        " displaying listchars
    set mouse=                                      " disable mouse
    set nolist                                      " wraps to whole words
    set noshowmode                                  " hide mode cmd line
    set noexrc                                      " don't use other .*rc(s)
    set nostartofline                               " keep cursor column pos
    set nowrap                                      " don't wrap lines
    set numberwidth=5                               " 99999 lines
    set shortmess+=I                                " disable startup message
    set splitbelow                                  " splits go below w/focus
    set splitright                                  " vsplits go right w/focus
    set ttyfast                                     " for faster redraws etc
    set ttymouse=xterm2                             " experimental
    set ruler                                       " show current pos at bottom
    set relativenumber                              " linenumbers are relative
    set modelines=0                                 " modelines sets the number of
                                                    " lines at the beginning and end
                                                    " of each file vim checks for
                                                    " initializations. basically
                                                    " for file-specific settings.


    " in order exiting insert mode in vim-airline wouldn't lag that much:
    " {{{
        if ! has('gui_running')
        set ttimeoutlen=10
        augroup FastEscape
            autocmd!
            au InsertEnter * set timeoutlen=0
            au InsertLeave * set timeoutlen=1000
        augroup END
        endif
    "}}}

    " autosave file if window loses focus:
    "au FocusLost * :wa
    
    """ Folding {{{
        set foldcolumn=0                            " hide folding column
        set foldmethod=indent                       " folds using indent
        set foldnestmax=10                          " max 10 nested folds
        set foldlevelstart=99                       " folds open by default
    """ }}}
    
    """ Search and replace {{{
        set gdefault                                " default s//g (global)
        set incsearch                               " "live"-search, ie incremental search
    """ }}}
    
    """ Matching {{{
        set matchtime=2                             " time to blink match {}
        set matchpairs+=<:>                         " for ci< or ci>
        set showmatch                               " tmpjump to match-bracket
    """ }}}
    
    """ Return to last edit position when opening files {{{
        autocmd BufReadPost *
            \ if line("'\"") > 0 && line("'\"") <= line("$") |
            \     exe "normal! g`\"" |
            \ endif
    """ }}}
""" }}}

""" Files {{{
    set autochdir                                   " always use curr. dir.
    set autoread                                    " refresh if changed
    set confirm                                     " confirm changed files
    set noautowrite                                 " never autowrite
    set nobackup                                    " disable backups
    set noswapfile                                  " disable swapfile
    set updatecount=50                              " update swp after 50chars
    """ Persistent undo. Requires Vim 7.3 {{{
        if has('persistent_undo') && exists("&undodir")
            set undodir=$HOME/.vim/undo/            " where to store undofiles
            set undofile                            " enable undofile
            set undolevels=500                      " max undos stored
            set undoreload=10000                    " buffer stored undos
        endif
    """ }}}
""" }}}

""" Text formatting {{{
    set textwidth=79
    set colorcolumn=85
    set formatoptions=qrn1
    set autoindent                                  " preserve indentation
    set backspace=indent,eol,start                  " smart backspace
    set cinkeys-=0#                                 " don't force # indentation
    set expandtab                                   " no real tabs
    set ignorecase                                  " by default ignore case
    set nrformats+=alpha                            " incr/decr letters C-a/-x
    set shiftround                                  " be clever with tabs
    set shiftwidth=4                                " default 8
    set smartcase                                   " sensitive with uppercase
    set smarttab                                    " tab to 0,4,8 etc.
    set softtabstop=4                               " "tab" feels like <tab>
    set tabstop=4                                   " replace <TAB> w/4 spaces
    """ Only auto-comment newline for block comments {{{
        au FileType c,cpp setlocal comments -=:// comments +=f://
    """ }}}
""" }}}

""" Keybindings {{{
    """ General {{{
        " Remap <leader>
        let mapleader=","

        " Quickly edit/source .vimrc
        noremap <leader>ve :edit $HOME/.vimrc<CR>
        noremap <leader>vs :source $HOME/.vimrc<CR>

        " Yank(copy) to system clipboard
        noremap <leader>y "+y

        " Toggle text wrapping
        nmap <silent> <leader>w :set invwrap<CR>:set wrap?<CR>

        " Toggle folding
        nnoremap <silent> <Space> @=(foldlevel('.')?'za':"\<Space>")<CR>
        vnoremap <Space> zf

        " Bubbling (bracket matching)
        nmap <C-up> [e
        nmap <C-down> ]e
        vmap <C-up> [egv
        vmap <C-down> ]egv

        " Move faster
        map <C-j> <C-d>
        map <C-k> <C-u>

        " Treat wrapped lines as normal lines
        nnoremap j gj
        nnoremap k gk

        " Working ci(, works for both breaklined, inline and multiple ()
        nnoremap ci( %ci(

        " We don't need any help!
        inoremap <F1> <nop>
        nnoremap <F1> <nop>
        vnoremap <F1> <nop>

        " Disable annoying ex mode (Q)
        map Q <nop>

        " Buffers, preferred over tabs now with bufferline.
        nnoremap gn :bnext<CR>
        nnoremap gN :bprevious<CR>
        nnoremap gd :bdelete<CR>
        nnoremap gf <C-^>
        
        " This is totally awesome - remap jj to escape in insert mode.
        inoremap jj <Esc>
        
        " unhighlight searchresult (2 bindings)
        nmap <silent> ,/ :nohlsearch<CR>
        nnoremap <leader><space> :noh<cr>
        
        " Remap tab to bracket matching:
        " (currently disabled since YCM plugin uses tab)
        "nnoremap <tab> %
        "vnoremap <tab> %
        
        " Turn off vim's default regex handling:
        nnoremap / /\v
        vnoremap / /\v
        
        " Disable arrow keys:
        nnoremap <up> <nop>
        nnoremap <down> <nop>
        nnoremap <left> <nop>
        nnoremap <right> <nop>
        inoremap <up> <nop>
        inoremap <down> <nop>
        inoremap <left> <nop>
        inoremap <right> <nop>
        
        " avoid typos:
        nnoremap ; :
        
        " Go to the middle of the line
        nmap gm :exe 'normal '.(virtcol('$')/2).'\\|'<CR>
        
    """ }}}
    
    """ Window movement/maangement {{{
        " Create a vertical split and start using it
        nnoremap <leader>w <C-w>v<C-w>l
        
        " Create a horizontal split and start using it
        nnoremap <leader>s <C-w>s<C-w>j
        
        " Navigate splits:
        nnoremap <C-h> <C-w>h
        nnoremap <C-j> <C-w>j
        nnoremap <C-k> <C-w>k
        nnoremap <C-l> <C-w>l
        
        " map shift j&k to prev/next buffer:
        map <S-J> :bp <CR>
        map <S-K> :bn <CR>
        
    """ }}}
    
    """ Tabs {{{
        " tab switching:
        map <A-1> <Esc>:tabn 1<CR>i
        map <A-2> <Esc>:tabn 2<CR>i
        map <A-3> <Esc>:tabn 3<CR>i
        map <A-4> <Esc>:tabn 4<CR>i
        map <A-5> <Esc>:tabn 5<CR>i
        map <A-6> <Esc>:tabn 6<CR>i
        map <A-7> <Esc>:tabn 7<CR>i
        map <A-8> <Esc>:tabn 8<CR>i
        map <A-9> <Esc>:tabn 9<CR>i
        
        " New tab:
        nnoremap <C-S-t> :tabnew<CR>
        inoremap <C-S-t> <Esc>:tabnew<CR>
        
        " Close tab:
        "nnoremap <C-S-w> <Esc>:tabclose<CR>
        
        nnoremap th  :tabfirst<CR>
        nnoremap tj  :tabnext<CR>
        nnoremap tk  :tabprev<CR>
        nnoremap tl  :tablast<CR>
        nnoremap tt  :tabedit<Space>
        nnoremap tn  :tabnext<Space>
        nnoremap tm  :tabm<Space>
        nnoremap td  :tabclose<CR>
        
        " Move to prev/next tabpage:
        nnoremap <S-h> gT
        nnoremap <S-l> gt
        

        
    """ }}}
    
    """ Functions or fancy binds {{{
        """ Toggle syntax highlighting {{{
            function! ToggleSyntaxHighlighthing()
                if exists("g:syntax_on")
                    syntax off
                else
                    syntax on
                    call CustomHighlighting()
                endif
            endfunction

            nnoremap <leader>s :call ToggleSyntaxHighlighthing()<CR>
        """ }}}
        
        """ Highlight characters past 79, toggle with <leader>h
        """ You might want to override this function and its variables with
        """ your own in .vimrc.last which might set for example colorcolumn or
        """ even the textwidth. See https://github.com/timss/vimconf/pull/4 {{{
            let g:overlength_enabled = 0
            highlight OverLength ctermbg=238 guibg=#444444

            function! ToggleOverLength()
                if g:overlength_enabled == 0
                    match OverLength /\%79v.*/
                    let g:overlength_enabled = 1
                    echo 'OverLength highlighting turned on'
                else
                    match
                    let g:overlength_enabled = 0
                    echo 'OverLength highlighting turned off'
                endif
            endfunction

            nnoremap <leader>h :call ToggleOverLength()<CR>
        """ }}}
        
        """ Toggle relativenumber using <leader>r {{{
            nnoremap <leader>r :call NumberToggle()<CR>

            function! NumberToggle()
                if(&relativenumber == 1)
                    set number
                else
                    set relativenumber
                endif
            endfunction
        """ }}}
        
        """ Remove multiple empty lines {{{
            function! DeleteMultipleEmptyLines()
                g/^\_$\n\_^$/d
            endfunction

            nnoremap <leader>ld :call DeleteMultipleEmptyLines()<CR>
        """ }}}
        
        """ Split to relative header/source {{{
            function! SplitRelSrc()
                let s:fname = expand("%:t:r")

                if expand("%:e") == "h"
                    set nosplitright
                    exe "vsplit" fnameescape(s:fname . ".cpp")
                    set splitright
                elseif expand("%:e") == "cpp"
                    exe "vsplit" fnameescape(s:fname . ".h")
                endif
            endfunction

            nnoremap <leader>le :call SplitRelSrc()<CR>
        """ }}}
        
        """ Strip trailing whitespace, return to cursors at save {{{
            function! <SID>StripTrailingWhitespace()
                let l = line(".")
                let c = col(".")
                %s/\s\+$//e
                call cursor(l, c)
            endfunction

            autocmd FileType c,cpp,conf,css,html,perl,python,sh autocmd 
                        \BufWritePre <buffer> :call <SID>StripTrailingWhitespace()
        """ }}}
    """ }}}
    
    """ Plugins {{{
        " Toggle tagbar (definitions, functions etc.)
        map <F1> :TagbarToggle<CR>
        nmap <F8> :TagbarToggle<CR>

        " Toggle pastemode, doesn't indent
        set pastetoggle=<F3>

        " Syntastic - toggle error list. Probably should be toggleable.
        noremap <silent><leader>lo :Errors<CR>
        noremap <silent><leader>lc :lcl<CR>
        
        " NERDtree toggle:
        map <C-n> :NERDTreeToggle<CR>
        
        " Gundo toggle:
        nnoremap <F5> :GundoToggle<CR>
        
    """ }}}
""" }}}

""" Plugin settings {{{
    " Startify, the fancy start page
    let g:ctrlp_reuse_window = 'startify' " don't split in startify
    let g:startify_bookmarks = [
        \ $HOME . "/.vimrc", $HOME . "/.vimrc.first",
        \ $HOME . "/.vimrc.last", $HOME . "/.vimrc.plugins"
        \ ]
    let g:startify_custom_header = [
        \ '   Author:               LA',
        \ '   Original source:      http://github.com/timss/vimconf',
        \ ''
        \ ]

    " CtrlP - don't recalculate files on start (slow)
    let g:ctrlp_clear_cache_on_exit = 0
    let g:ctrlp_working_path_mode = 'ra'
    
    " Start ctrlp in find buffer mode
    let g:ctrlp_cmd = 'CtrlPBuffer'
    
    " Start ctrlp in MRU file mode
    "let g:ctrlp_cmd = 'CtrlPMRU'
    
    let g:ctrlp_regexp = 1
    
    " ???
    let g:ctrlp_switch_buffer = 'Et'

    " airline - automatically populate g:airline_symbols dictionary w/
    " powerline symbols:
    let g:airline_powerline_fonts = 1

    " TagBar
    let g:tagbar_left = 0
    let g:tagbar_width = 30
    set tags=tags;/

    " ultisnips trigger conf; do not use <tab> if you use YouCompleteMe! {{{
        function! g:UltiSnips_Complete()
            call UltiSnips#ExpandSnippet()
            if g:ulti_expand_res == 0
                if pumvisible()
                    return "\<C-n>"
                else
                    call UltiSnips#JumpForwards()
                    if g:ulti_jump_forwards_res == 0
                    return "\<TAB>"
                    endif
                endif
            endif
            return ""
        endfunction

        au BufEnter * exec "inoremap <silent> " . g:UltiSnipsExpandTrigger . " <C-R>=g:UltiSnips_Complete()<cr>"
        let g:UltiSnipsJumpForwardTrigger="<tab>"
        let g:UltiSnipsListSnippets="<c-e>"
        " this mapping Enter key to <C-y> to chose the current highlight item 
        " and close the selection list, same as other IDEs.
        " CONFLICT with some plugins like tpope/Endwise
        inoremap <expr> <CR> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"
    "}}}

    " alternative to the previous:
    "let g:UltiSnipsExpandTrigger="<c-j>""
    "let g:UltiSnipsJumpForwardTrigger="<c-j>"
    "let g:UltiSnipsJumpBackwardTrigger="<c-k>"

    " If you want :UltiSnipsEdit to split your window.
    let g:UltiSnipsEditSplit="vertical" 



    " YouCompleteMe:
    " open default ycm_extra_conf, so every project doesn't request
    " explicitly its own:
    "let g:ycm_global_ycm_extra_conf = '~/.ycm_extra_conf.py'

    " Removes YCM's syntax checking for C-family languages, as it breaks the
    " syntastic's syntax checker:
    let g:ycm_show_diagnostics_ui = 0



    " Syntastic - This is largely up to your own usage, and override these
    "             changes if be needed. This is merely an exemplification.
    let g:syntastic_check_on_open = 1
    let g:syntastic_enable_signs = 1

    let g:syntastic_c_checkers = ['gcc']
    let g:syntastic_c_check_header = 1
    let g:syntastic_c_auto_refresh_includes = 1

    let g:syntastic_python_checkers = ['flake8', 'python']


    let g:syntastic_cpp_check_header = 1
    let g:syntastic_cpp_compiler_options = ' -std=c++0x'
    let g:syntastic_mode_map = {
        \ 'mode': 'passive',
        \ 'active_filetypes':
            \ ['c', 'cpp', 'perl', 'python'] }


    " Automatically remove preview window after autocomplete (mainly for clang_complete)
    autocmd CursorMovedI * if pumvisible() == 0|pclose|endif
    autocmd InsertLeave * if pumvisible() == 0|pclose|endif
""" }}}

""" Local ending config, will overwrite anything above. Generally use this. {{{{
    if filereadable($HOME."/.vimrc.last")
        source $HOME/.vimrc.last
    endif
""" }}}
