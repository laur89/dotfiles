
" We use Vim settings
" TODO: check this out: https://github.com/skwp/dotfiles
" quite sure this was the base config:  https://github.com/timss/vimconf/blob/master/.vimrc
"
"
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

            " make directory for the persistent undo storage (not related to vundle)...
            silent !mkdir -p $HOME/.vim/undo
            " ...and for tags (used by vim-easytags):
            silent !mkdir -p $HOME/.vim/tags
        endif
    """ }}}

    """ Initialize Vundle {{{
        filetype off                                " required to init
        set rtp+=$HOME/.vim/bundle/Vundle.vim       " include vundle
        call vundle#begin()                         " init vundle
    """ }}}

    """ Github repos, uncomment to disable a plugin {{{
    " consider NeoBundle
    Plugin 'gmarik/Vundle.vim'

    """ Local plugins (and only plugins in this file!) {{{
        if filereadable($HOME."/.vimrc.plugins")
            source $HOME/.vimrc.plugins
        endif
    """ }}}

    " Edit files using sudo/su
    "Plugin 'chrisbra/SudoEdit.vim'

    " Fuzzy finder (files, mru, etc)
    "Plugin 'kien/ctrlp.vim'  " kien/ repo (the original one) seems dead.
    Plugin 'ctrlpvim/ctrlp.vim'

    " A pretty statusline, bufferline integration:
    "Plugin 'itchyny/lightline.vim' "liiga minimalist mu jaoks
    " !! use either vim-airline OR powerline !!
    "   also, pwrline needs to be installed EITHER with vundle OR by pip, never /w both
    Plugin 'bling/vim-airline'
    Plugin 'bling/vim-bufferline'

    " Easy... motions... yeah.
    Plugin 'Lokaltog/vim-easymotion'

    " TODO: check out this alternative to easymotion:
    "Plugin  'justinmk/vim-sneak'

    " Glorious colorscheme
    Plugin 'nanotech/jellybeans.vim'

    " Super easy commenting, toggle comments etc
    Plugin 'scrooloose/nerdcommenter'

    " Autoclose (, " etc; ie when you insert an (, then ) will be automatically
    " inserted, and cursor placed between them;
    "Plugin 'Townk/vim-autoclose'
    " uses delimitMate instead of vim-autoclose, if you use YCM (they conflict):
    Plugin 'Raimondi/delimitMate'

    " Git wrapper inside Vim
    Plugin 'tpope/vim-fugitive'

    " better git log borwser (hit :gitv)
    " !!! depfnds on tpope/fugitive !!!
    Plugin 'gregsexton/gitv'

    " Handle surround chars like ''
    Plugin 'tpope/vim-surround'

    " Align your = etc.
    Plugin 'vim-scripts/Align'

    " Snippets like textmate
    "Plugin 'MarcWeber/vim-addon-mw-utils' "vim-snipmate depends on this one
    "Plugin 'tomtom/tlib_vim'              " ... and this.
    Plugin 'honza/vim-snippets'           " The snippets repo, and...
    Plugin 'SirVer/ultisnips'             "...the engine.

    " A fancy start screen, shows MRU etc:
    Plugin 'mhinz/vim-startify'

    " Vim signs (:h signs) for modified lines based off VCS (e.g. Git)
    " for git-only usage, better look for vim-gitgutter
    Plugin 'mhinz/vim-signify'

    " git-only support similar to vim-signify (only use one of them!)
    "Plugin 'airblade/vim-gitgutter'

    " Awesome syntax checker.
    " REQUIREMENTS: See :h syntastic-intro
    Plugin 'scrooloose/syntastic'

    " Functions, class data etc.
    " REQUIREMENTS: (exuberant)-ctags
    Plugin 'majutsushi/tagbar'

    " Ctags generator/highlighter (note the vim-misc is dependency for it)
    Plugin 'xolox/vim-misc'
    Plugin 'xolox/vim-easytags' " alternative shoud be taginator?
    Plugin 'xolox/vim-session'
    Plugin 'xolox/vim-notes'

    " Selfexplanatory...
    Plugin 'jlanzarotta/bufexplorer'

    " File browser
    Plugin 'scrooloose/nerdtree'

    " Visualise the undo tree
    Plugin 'sjl/gundo.vim'

    " fast mechanism to open files and buffers.
    " requires compiling - read the docs/wiki!
    " perhaps time to deprecate for ctrl-p?
    Plugin 'wincent/Command-T'

    " development completion engine (integrates with utilsnips and deprecates
    " supertab et al; needs compilation! read the docs!:
    " !!! ühed väidavad, et javaphp,js,html jaoks on neocomplete parem;
    Plugin 'Valloric/YouCompleteMe'

    " Go-lang/golang/go lang support:
    Plugin 'fatih/vim-go'

    " C# support:
    Plugin 'OmniSharp/omnisharp-vim'

    " Node.js:
    Plugin 'moll/vim-node'

    " js beautifier:
    Plugin 'jsbeautify'

    " navigate seamlessly btw vim & tmux splits (don't forget tmux bindings as well):
    Plugin 'christoomey/vim-tmux-navigator'

    " supertab: (only so YCM and UltiSnips could play along, otherwise don't need)
    " <Tab> everything!
    Plugin 'ervandew/supertab'

    " yankring: hold copy of yanked elements:
    " alternative: yankstack
    Plugin 'vim-scripts/YankRing.vim'
    "Plugin 'maxbrunsfeld/vim-yankstack'

    " show location of the marks: (! requires compilation with +signs)
    " !!! deprecated by vim-signature?
    "Plugin 'showmarks'

    " show, place and toggle marks: (! requires compilation with +signs)
    Plugin 'kshenoy/vim-signature'

    " camel case movements:
    Plugin 'bkad/CamelCaseMotion'

    " typos:
    "Plugin 'chip/vim-fat-finger'

    " rainbow parnes:
    "Plugin 'kien/rainbow_parentheses.vim'
    Plugin 'luochen1990/rainbow'

    " tern for vim (tern is a standalone js analyzer)
    " depends on tern!
    Plugin 'marijnh/tern_for_vim'

    " easy find and replace across multiple files
    " alternative - greplace
    Plugin 'dkprice/vim-easygrep'

    " visual-star-search - search words selected in visual mode:
    Plugin 'bronson/vim-visual-star-search'

    " front for ag, aka the silver_searcher:
    " depends on the_silver_searcher - apt-get install silversearcher-ag   proj @ ggreer/the_silver_searcher
    Plugin 'rking/ag.vim'

    " manipulate on blocks based on their indentation:
    " use  vai  and vii
    Plugin 'michaeljsmith/vim-indent-object'

    " provides text-object 'a' (argument) - you can delete, change, select etc in
    " familiar ways;, eg daa, cia,...
    Plugin 'vim-scripts/argtextobj.vim'

    " gives 'f' textobj so vaf to select javascript function
    Plugin 'thinca/vim-textobj-function-javascript'

    " better jquery syntax highlighting:
    Plugin 'jQuery'

    Plugin 'jelera/vim-javascript-syntax'

    " show search window as 'at match # out of # matches':
    Plugin 'henrik/vim-indexed-search'

    " tab completion in search:
    Plugin 'vim-scripts/SearchComplete' "TODO: currently doesn't work!

    " adds . (repeat) functionality to more complex commands instead of the native-only ones:
    Plugin 'tpope/vim-repeat'

    " ends if-blocks etc for few langs:
    Plugin 'tpope/vim-endwise'

    " vim sugar for unix shell commands:
    Plugin 'tpope/vim-eunuch'

    " asyn jobs
    Plugin 'tpope/vim-dispatch'

    " add :CopyPath and :CopyFileName commands
    Plugin 'vim-scripts/copypath.vim'

    " project specific vimrc:
    Plugin 'LucHermitte/lh-vim-lib' " dependency for local_vimrc
    Plugin 'LucHermitte/local_vimrc'

    " puppet syntax highlight, formatting...
    Plugin 'rodjek/vim-puppet'

    " vim multidiff in tabs:
    "Plugin 'xenomachina/public/tree/master/vim/plugin'
    " consider targets.vim - adds new text objects

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
        colors jellybeans                           " select colorscheme
        """ force behavior and filetypes, and by extension highlighting {{{
            augroup FileTypeRules
                autocmd!
                au BufNewFile,BufRead *.txt se ft=sh tw=79  " opens .txt w/highlight
                au BufNewFile,BufRead *.tex se ft=tex tw=79 " we don't want plaintex
                au BufNewFile,BufRead *.md se ft=markdown tw=79 " markdown, not modula
                " per filetype colors:
                " these next schemes come from   https://github.com/sentientmachine/erics_vim_syntax_and_color_highlighting
                " note they came with their own syntax files also (create syntax/ dir in .vim):
                "au BufReadPost *.py colorscheme molokai
                "au BufReadPost *.html colorscheme monokai
                "au BufReadPost *.java colorscheme monokai
                "au BufReadPost *.php colorscheme monokai
                "au BufReadPost *.js colorscheme Mango
            augroup END
        """ }}}

        """ 256 colors for maximum jellybeans bling. See commit log for info {{{
            "if (&term =~ "xterm") || (&term =~ "screen")
            "    set t_Co=256
            "endif

            " Use 256 colours (Use this setting only if your terminal supports 256 colours)
            " (currently overrides the above if-block):
            set t_Co=256
        """ }}}

        """ Tab colors   (overwritten by lightline?) {{{ "currently disabled because of airline tab extension
                "hi TabLineFill ctermfg=NONE ctermbg=233
                "hi TabLine ctermfg=241 ctermbg=233
                "hi TabLineSel ctermfg=250 ctermbg=233
        """ }}}

        """ Custom highlighting, where NONE uses terminal background {{{
            function! CustomHighlighting()
                highlight Normal ctermbg=NONE
                highlight NonText ctermbg=NONE
                highlight LineNr ctermbg=NONE
                highlight SignColumn ctermbg=NONE
                highlight SignColumn guibg=#151515
                highlight CursorLine ctermbg=235
            endfunction

            call CustomHighlighting()
        """ }}}
    """ }}}

    """ Interface general interface {{{
        " !!! cursorline & -column & relativelinenr can make vim super-laggy, especially if using huge tags file
        set cursorline                              " hilight cursor line
        set cursorcolumn                            " hilight cursor col
        set more                                    " ---more--- like less
        set number                                  " line numbers
        set relativenumber                          " linenumbers are relative
        set scrolloff=3                             " lines above/below cursor
        set showcmd                                 " show cmds being typed
        set title                                   " window title
        set vb t_vb=                                " disable beep and flashing
        set wildignore=.bak,.pyc,.o,.ojb,.a,
                       \.pdf,.jpg,.gif,.png,.jpeg,
                       \.avi,.mkv,.so               " ignore said files for tab completion
        set wildmenu                                " better auto complete
        set wildmode=longest,list                   " bash-like auto complete
        set equalalways                             " keep splits equally sized

        """ Encoding {{{
            " If you're having problems with some characters you can force
            " UTF-8 if your locale is something else.
            " WARNING: this will affect encoding used when editing files!
            "
            " set encoding=utf-8                    " for character glyphs; default $LANG/latin1
            " set fileencoding=utf-8                " default none
        """ }}}

        """ Gvim {{{
            "set guifont=DejaVu\ Sans\ Mono\ 9
            set guifont=Terminess\ Powerline\ 10
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
    if !has('nvim')
        set ttymouse=xterm2                         " experimental
    endif
    set ruler                                       " show current pos at bottom
    set modelines=0                                 " modelines sets the number of
                                                    " lines at the beginning and end
                                                    " of each file vim checks for
                                                    " initializations. basically
                                                    " for file-specific settings.
    set viminfo+=n~/.vim/viminfo


    """ In order exiting insert mode in vim-airline/bufferline wouldn't lag that much: {{{
        if ! has('gui_running')
            set ttimeoutlen=10
            augroup FastEscape
                autocmd!
                au InsertEnter * set timeoutlen=0
                au InsertLeave * set timeoutlen=1000
            augroup END
        endif
    """ }}}

    " autosave file if window loses focus:
    "au FocusLost * :wa

    " auto-reload vimrc on save:
    autocmd! BufWritePost ~/.vimrc nested :source ~/.vimrc

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
        augroup LastPosition
            autocmd! BufReadPost *
                \ if line("'\"") > 0 && line("'\"") <= line("$") |
                \     exe "normal! g`\"" |
                \ endif
        augroup END
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
    set textwidth=85
    set colorcolumn=85
    set formatoptions=qrn1j
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
        augroup AutoBlockComment
            autocmd! FileType c,cpp setlocal comments -=:// comments +=f://
        augroup END
    """ }}}
""" }}}

""" Keybindings {{{
    """ General {{{
        " Remap <leader>
        let mapleader=","

        " Quickly edit/source .vimrc
        noremap <leader>ve :edit $HOME/.vimrc<CR>
        noremap <leader>vs :source $HOME/.vimrc<CR>

        " Yank(copy) to system clipboard (implies visual mode)
        noremap <leader>y "+y

        " Y -> yank from cursor to EOL (instead of same as yy)
        noremap Y y$

        " Toggle text wrapping
        nmap <silent> <leader>w :set invwrap<CR>:set wrap?<CR>

        " Toggle folding
        nnoremap <silent> <Space> @=(foldlevel('.')?'za':"\<Space>")<CR>
        vnoremap <Space> zf

        " buffer delete fix (fix as in won't exit the window when dropping buffer, eg
        " with NerdTree):
        nnoremap <leader>q :bp<cr>:bd #<cr>

        " Bubbling (bracket matching)
        nmap <C-up> [e
        nmap <C-down> ]e
        vmap <C-up> [egv
        vmap <C-down> ]egv

        " Move faster (overridden by the tmux split navigation)
        "map <C-j> <C-d>
        "map <C-k> <C-u>

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

        " move in insert mode:
        " (disabled now, co c-j/k could be used in YCM list)
        "imap <C-h> <C-o>h
        "imap <C-j> <C-o>j
        "imap <C-k> <C-o>k
        "imap <C-l> <C-o>l

        " avoid typos:
        nnoremap ; :

        " Go to the middle of the line TODO: doesnt work
        nmap gm :exe 'normal '.(virtcol('$')/2).'\\|'<CR>

    """ }}}

    """ Window movement/management {{{
        " Create a vertical split and start using it
        nnoremap <leader>v <C-w>v<C-w>l
        "nnoremap <leader>w <C-w>v<C-w>l

        " Create a horizontal split and start using it
        nnoremap <leader>s <C-w>s<C-w>j

        " Navigate splits:
        nnoremap <C-h> <C-w>h
        nnoremap <C-j> <C-w>j
        nnoremap <C-k> <C-w>k
        nnoremap <C-l> <C-w>l

        " map shift+j/k to prev/next buffer:
        map <S-J> :bn <CR>
        map <S-K> :bp <CR>

    """ }}}

    """ Tabs {{{
        " tab switching:
        map <A-1> <Esc>:tabn 1<CR>
        map <A-2> <Esc>:tabn 2<CR>
        map <A-3> <Esc>:tabn 3<CR>
        map <A-4> <Esc>:tabn 4<CR>
        map <A-5> <Esc>:tabn 5<CR>
        map <A-6> <Esc>:tabn 6<CR>
        map <A-7> <Esc>:tabn 7<CR>
        map <A-8> <Esc>:tabn 8<CR>
        map <A-9> <Esc>:tabn 9<CR>

        " New tab:
        nnoremap <C-S-t> :tabnew<CR>
        inoremap <C-S-t> <Esc>:tabnew<CR>

        " Close tab:
        "nnoremap <C-S-w> <Esc>:tabclose<CR>

        nnoremap th  :tabfirst<CR>
        nnoremap tj  :tabnext<CR>
        nnoremap tk  :tabprev<CR>
        nnoremap tl  :tablast<CR>
        nnoremap tt  :tabedit<CR>
        nnoremap tn  :tabnext<CR>
        nnoremap tm  :tabm<Space> "tabmove
        nnoremap td  :tabclose<CR>

        " Move to prev/next tabpage:
        nnoremap <S-h> gT
        nnoremap <S-l> gt


    """ }}}

    " Maps to resizing a window split (Warn: conflict with indentation)
    if bufwinnr(1)
        "map <silent> < <C-w><
        map <silent> - <C-W>-
        map <silent> + <C-W>+
        "map <silent> > <C-w>>
    endif

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
                "(currently incative because of nerdtree binding)
            "nnoremap <leader>r :call NumberToggle()<CR>

            "function! NumberToggle()
                "if(&relativenumber == 1)
                    "set number
                "else
                    "set relativenumber
                "endif
            "endfunction
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

            augroup StripTrailingWhitespace
                autocmd!
                autocmd FileType c,cpp,conf,css,html,perl,ruby,python,sh,javascript
                            \ autocmd BufWritePre <buffer> :call
                            \ <SID>StripTrailingWhitespace()
            augroup END
        """ }}}

        """ set binds to copy/paste to system clipboard: {{{
            " <C-c> for copy (in visual), <leader><C-v>(in normal) for paste:
            if has('unix')
                vn <C-c> y:call system("xclip -i -selection clipboard", getreg("\""))<CR>:call system("xclip -i", getreg("\""))<CR>
                no <leader><C-v> :call setreg("\"",system("xclip -o -selection clipboard"))<CR>p
            elseif has('mac')
                vn <C-c> y:call system("pbcopy", getreg("\""))<CR>
                no <leader><C-v> :call setreg("\"",system("pbpaste"))<CR>p
            endif
        """ }}}

    """ }}}

    """ Plugins {{{
        " Toggle tagbar (definitions, functions etc.)
        map <F1> :TagbarToggle<CR>
        nmap <F8> :TagbarToggle<CR>

        " Toggle pastemode, doesn't indent
        "set pastetoggle=<F3>
        set pastetoggle=<F6>

        " Syntastic - toggle error list. Probably should be toggleable.
        noremap <silent><leader>lo :Errors<CR>
        noremap <silent><leader>lc :lcl<CR>

        " NERDtree toggle:
        map <C-n> :NERDTreeToggle<CR>
        map <leader>r :NERDTreeFind<cr> " move to currently opened file in nerdtree

        " Gundo toggle:
        nnoremap <F5> :GundoToggle<CR>

        " vim-tmux-navigator:
        nnoremap <silent> <c-h> :TmuxNavigateLeft<cr>
        nnoremap <silent> <c-j> :TmuxNavigateDown<cr>
        nnoremap <silent> <c-k> :TmuxNavigateUp<cr>
        nnoremap <silent> <c-l> :TmuxNavigateRight<cr>
        "nnoremap <silent> <todo> :TmuxNavigatePrevious<cr>

        " powerline (disable if using airline instead):
        "set rtp+=/usr/local/lib/python2.7/dist-packages/powerline/bindings/vim/

        " CamelCaseMotion: Replace the default 'w', 'b' and 'e' mappings instead of defining additional mappings ',w', ',b' and ',e': ...
        "map <silent> w <Plug>CamelCaseMotion_w
        "map <silent> b <Plug>CamelCaseMotion_b
        "map <silent> e <Plug>CamelCaseMotion_e
        "sunmap w
        "sunmap b
        "sunmap e
        " ...or define the <leader>-motion options:
        map <silent><leader> w <Plug>CamelCaseMotion_w
        map <silent><leader> b <Plug>CamelCaseMotion_b
        map <silent><leader> e <Plug>CamelCaseMotion_e

        " yankring:
        nnoremap <silent> <F11> :YRShow<CR> "displays the yankring window

    """ }}}
""" }}}

""" Plugin settings {{{
    " Startify, the fancy start page
    let g:startify_bookmarks = [
        \ $HOME . "/.vimrc", $HOME . "/.vimrc.first",
        \ $HOME . "/.vimrc.last", $HOME . "/.vimrc.plugins"
        \ ]
    let g:startify_custom_header = [
        \ '   Author:               la',
        \ '   Original vimconf:     http://github.com/timss/vimconf',
        \ ''
        \ ]

    " CtrlP
    "don't recalculate files on start (slow)
    let g:ctrlp_reuse_window = 'startify' "don't split in startify
    "let g:ctrlp_clear_cache_on_exit = 0
    let g:ctrlp_working_path_mode = 'ra'
    let g:ctrlp_root_markers = ['.ctrlp']  "consider this, since .git isn't as good with submodules; note this is IN ADDITION to the default ones
    "let g:ctrlp_working_path_mode = ""
    "let g:ctrlp_dotfiles = 0
    let g:ctrlp_max_files = 0
    "TODO: confirm these:
    let g:ctrlp_user_command = ['.git/', 'cd %s && git ls-files --exclude-standard -co']
    "let g:ctrlp_user_command = "find %s -type f | egrep -v '/\.(git|hg|svn)|solr|tmp/' | egrep -v '/\.(git|hg|svn)|solr|tmp/' | egrep -v '\.(png|exe|jpg|gif|jar|class|swp|swo|log|gitkep|keepme|so|o)$'"
    " Start ctrlp in find buffer mode
    let g:ctrlp_cmd = 'CtrlPBuffer'  "buffer: CtrlPBuffer  mru: CtrlPMRU
    " Start ctrlp in MRU file mode
    "let g:ctrlp_cmd = 'CtrlPMRU'
    let g:ctrlp_regexp = 1
    " ???:
    let g:ctrlp_switch_buffer = 'Et'
    let g:ctrlp_extensions = ['tag']    " enables tag browsing


    " yankring:
    " remap c-p so CtrlP could use it:
    " TODO: think of an actual mappings!:
    let g:yankring_replace_n_pkey = '<leader>p'
    let g:yankring_replace_n_nkey = '<leader>P'
    let g:yankring_history_dir = '$HOME/.vim'
    let g:yankring_max_history = 1000

    " yankstack (if using this, perhaps lose the yankring stuff?):
    "nmap <leader>p <Plug>yankstack_substitute_older_paste
    "nmap <leader>P <Plug>yankstack_substitute_newer_paste

    " vim-airline - automatically populate g:airline_symbols dictionary w/
    " powerline symbols:
    let g:airline_powerline_fonts = 1
    let g:airline_theme='dark'
    " integrate with https://github.com/edkolev/tmuxline.vim:
    "let g:airline#extensions#tmuxline#enabled = 1
    let g:airline#extensions#bufferline#enabled = 0
    "let g:airline#extensions#bufferline#overwrite_variables = 1
    let g:airline#extensions#tabline#enabled = 1

    " bufferline:
    let g:bufferline_active_buffer_left = '['
    let g:bufferline_active_buffer_right = ']'
    let g:bufferline_modified = '+'
    let g:bufferline_show_bufnr = 0
    let g:bufferline_rotate = 1  " scrolling with fixed current buf position
    let g:bufferline_inactive_highlight = 'StatusLineNC'
    let g:bufferline_active_highlight = 'StatusLine'
    let g:bufferline_echo = 1
    let g:bufferline_fixed_index = 0 "always first

    " TagBar
    let g:tagbar_left = 0
    let g:tagbar_width = 30

    " vim-easytags:
    set tags=./.tags;,~/.vimtags
    let g:easytags_dynamic_files = 1 " search for project specific tags; relative to wd or buffer!
    let g:easytags_by_filetype = '~/.vim/tags' " TODO: how to use with jsctags?; also fyi -  dynamic_files takes precedence over this
    let g:easytags_always_enabled = 1
    let g:easytags_on_cursorhold = 1
    let g:easytags_async = 1
    "let g:easytags_include_members = 1
    "let g:easytags_autorecurse = 1 "!!! makes stuff slooooow
    "let g:easytags_events = ['BufWritePost']
    "let g:easytags_languages = {
                "\   'javascript': {
                "\     'cmd': 'jsctags',
                "\       'args': ['-f', '$HOME/.vim/tags/javascript'],
                "\   },
                "\   'haskell': {
                "\       'cmd': '~/.cabal/bin/lushtags',
                "\       'args': [],
                "\       'fileoutput_opt': '-f',
                "\       'stdout_opt': '-f-',
                "\       'recurse_flag': '-R'
                "\   }
                "\}

    " eclim:
    " eclim completon registration to vim's omni complete which YCM automatically detects:
    let g:EclimCompletionMethod = 'omnifunc'


    """"""""" /ultisnips-YCM
    "" one solution for YCM and UltiSnips conflict (from http://stackoverflow.com/questions/14896327/ultisnips-and-youcompleteme/18685821#18685821):
    """ ultisnips trigger conf; do not use <tab> if you use YouCompleteMe! {{{
            "function! g:UltiSnips_Complete()
                "call UltiSnips#ExpandSnippet()
                "if g:ulti_expand_res == 0
                    "if pumvisible()
                        "return "\<C-n>"
                    "else
                        "call UltiSnips#JumpForwards()
                        "if g:ulti_jump_forwards_res == 0
                        "return "\<TAB>"
                        "endif
                    "endif
                "endif
                "return ""
            "endfunction

            "au BufEnter * exec "inoremap <silent> " . g:UltiSnipsExpandTrigger . " <C-R>=g:UltiSnips_Complete()<cr>"
            "let g:UltiSnipsJumpForwardTrigger="<tab>"
            "let g:UltiSnipsListSnippets="<c-e>"
            "" this mapping Enter key to <C-y> to chose the current highlight item
            "" and close the selection list, same as other IDEs.
            "" CONFLICT with some plugins like tpope/Endwise
            "inoremap <expr> <CR> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"
            "

        " another solution form the same stackOverflow topic:
        " make YCM compatible with UltiSnips (using supertab):
        let g:ycm_key_list_select_completion = ['<C-j>', '<Down>']
        let g:ycm_key_list_previous_completion = ['<C-k>', '<Up>']
        let g:SuperTabDefaultCompletionType = '<C-j>' "enables us to use tab to cycle through non-ultisnip items

        " better key bindings for UltiSnipsExpandTrigger
        let g:UltiSnipsExpandTrigger = "<tab>"
        let g:UltiSnipsJumpForwardTrigger = "<tab>"
        let g:UltiSnipsJumpBackwardTrigger = "<s-tab>"

        " alternative to the previous:
        "let g:UltiSnipsExpandTrigger="<c-j>""
        "let g:UltiSnipsJumpForwardTrigger="<c-j>"
        "let g:UltiSnipsJumpBackwardTrigger="<c-k>"

        " If you want :UltiSnipsEdit to split your window.
        let g:UltiSnipsEditSplit="vertical"
    """ }}}  /ultisnips-YCM


    " vim-tmux-navigator:
    let g:tmux_navigator_no_mappings = 1
    let g:tmux_navigator_save_on_switch = 1

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
    let g:syntastic_bash_checkers = ['shellcheck', 'checkbashisms']
    let g:syntastic_sh_checkers = ['shellcheck', 'checkbashisms']
    let g:syntastic_javascript_checkers = ['jshint']
    let g:syntastic_css_checkers = ['csslint']

    let g:syntastic_cpp_check_header = 1
    "let g:syntastic_cpp_compiler_options = ' -std=c++0x'
    "
    " note go in passive list, as vim-go is installed;
    let g:syntastic_mode_map = {
        \ 'mode': 'active',
        \ 'passive_filetypes':
            \ ['java','go'] }

    "let g:syntastic_mode_map = {
        "\ 'mode': 'passive',
        "\ 'active_filetypes':
            "\ ['c', 'cpp', 'perl', 'python'] }

    "let g:syntastic_mode_map = {
        "\ 'mode': 'passive',
        "\ 'active_filetypes': [],
        "\ 'passive_filetypes': [] } }


    " Session management options (vim-session):
    " if you don't want help windows to be restored:
    set sessionoptions-=help
    " by default, don't ask to save sessions:
    let g:session_autosave = 'no'
    " session data store:
    let g:session_directory = '~/.vim/sessions'  "default value; enforcing just in case

    " rainbow_parentheses:
    "let g:rbpt_colorpairs = [
        "\ ['brown',       'RoyalBlue3'],
        "\ ['Darkblue',    'SeaGreen3'],
        "\ ['darkgray',    'DarkOrchid3'],
        "\ ['darkgreen',   'firebrick3'],
        "\ ['darkcyan',    'RoyalBlue3'],
        "\ ['darkred',     'SeaGreen3'],
        "\ ['darkmagenta', 'DarkOrchid3'],
        "\ ['brown',       'firebrick3'],
        "\ ['gray',        'RoyalBlue3'],
        "\ ['black',       'SeaGreen3'],
        "\ ['darkmagenta', 'DarkOrchid3'],
        "\ ['Darkblue',    'firebrick3'],
        "\ ['darkgreen',   'RoyalBlue3'],
        "\ ['darkcyan',    'SeaGreen3'],
        "\ ['darkred',     'DarkOrchid3'],
        "\ ['red',         'firebrick3'],
        "\ ]
    "let g:rbpt_max = 16
    "let g:rbpt_loadcmd_toggle = 0

    "au VimEnter * RainbowParenthesesToggle
    "au Syntax * RainbowParenthesesLoadRound
    "au Syntax * RainbowParenthesesLoadSquare
    "au Syntax * RainbowParenthesesLoadBraces


    " rainbow:
    let g:rainbow_active = 1

    " copypath:
    "copy file path or name to unnamed register as well:
    let g:copypath_copy_to_unnamed_register = 1

    " Automatically remove preview window after autocomplete (mainly for clang_complete)
    augroup RemovePreview
        autocmd!
        autocmd CursorMovedI * if pumvisible() == 0|pclose|endif
        autocmd InsertLeave * if pumvisible() == 0|pclose|endif
    augroup END

    " vim-notes
    let g:notes_directories = ['/data/Dropbox/notes']
    let g:notes_suffix = '.note'

    " Ag (silver-searcher)
    " by default, start search from project root:
    let g:ag_working_path_mode='r'
    let g:ag_highlight=1
    let g:ag_prg="ag --vimgrep --smart-case"

    " vim-easygrep
    let g:EasyGrepRoot="search:.git,.svn,.hg,.ctrlp"
    "let g:EasyGrepCommand="ag --vimgrep --smart-case"  " does not support ag at the moment
    let g:EasyGrepWindow=0  " 0 -quickfix; 1 -location list
    "let g:EasyGrepWindowPosition="botleft lopen"
    let g:EasyGrepOpenWindowOnMatch=0
    let g:EasyGrepRecursive=1
    let g:EasyGrepMode=2 "search for files that are of a similar type to the current file

""" }}}

""" Local ending config, will overwrite anything above. Generally use this. {{{{
    if filereadable($HOME."/.vimrc.last")
        source $HOME/.vimrc.last
    endif
""" }}}
"
" !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
" !!!!! UNORGANISED STUFF:
" !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

