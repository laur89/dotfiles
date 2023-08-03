" vim: set ft=vimrc:

" default conf_dir to $HOME/.config/nvim/ if not defined:
let conf_dir = get(g:, 'conf_dir', $HOME.'/.config/nvim/')
if !isdirectory(conf_dir)
    silent execute '!mkdir -p '.conf_dir
endif

""" User interface {{{
    """ Syntax highlighting {{{
        filetype plugin indent on                   " load filetype plugins and indent settings
        syntax on                                   " syntax highlighting
        set background=dark                         " we're using a dark bg
        if !exists("$__REMOTE_SSH")
            "colors jellybeans                           " select colorscheme
            colors gruvbox                           " select colorscheme
        endif
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

        """ 256 colors for maximum color (eg jellybeans) bling. See commit log for info {{{
            "if (&term =~ "xterm") || (&term =~ "screen")
            "    set t_Co=256
            "endif

            " Use 256 colours (Use this setting only if your terminal supports 256 colours)
            " (currently overrides the above if-block):
            set t_Co=256
        """ }}}

        """ Tab colors   (overwritten by lightline?) {{{ "comment out if using airline tab extension
                hi TabLineFill ctermfg=NONE ctermbg=233
                hi TabLine ctermfg=241 ctermbg=233
                hi TabLineSel ctermfg=250 ctermbg=233
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
        set cursorline                              " highlight cursor line
        "set cursorcolumn                            " highlight cursor col
        set more                                    " ---more--- like less
        set number                                  " line numbers
        set relativenumber                          " linenumbers are relative
        set scrolloff=3                             " lines above/below cursor
        set showcmd                                 " show cmds being typed
        set cmdheight=2                             " Give more space for displaying messages
        set updatetime=300                          " default is 4000; longer values can lead to noticeable delays and poor UX
        set clipboard+=unnamed                      " use os clipboard by default;
                                                    " change to 'unnamedplus' to use
                                                    " system clipboard for all
                                                    " operations (delete, yank, you
                                                    " name it).
        set title                                   " window title
        set vb t_vb=                                " disable beep and flashing
        set wildignore+=.bak,.pyc,.o,.ojb,.a,.orig,
                       \.pdf,.jpg,.gif,.png,.jpeg,
                       \.avi,.mkv,.so,
                       \*/node_modules/*,*/vendor/* " ignore said files for tab completion
        set wildmenu                                " better auto complete
        "set wildmode=longest:full                   " bash-like auto complete
        "set wildmode=list:longest,list:full
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
            set guifont=DejaVu\ Sans\ Mono:h9       " note this :h<size> syntax is at least for 'neovide' (sic!), unsure if it works for other GUIs
            "set guifont=Terminess\ Powerline\ 10
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
    set shortmess+=c                                " Don't pass messages to |ins-completion-menu| (as per coc recommendation)
    "set shortmess-=S                                " show 1/n count in statusbar when searching? TODO not working? was recommended in https://github.com/google/vim-searchindex
    set splitbelow                                  " splits go below w/focus
    set splitright                                  " vsplits go right w/focus
    set ttyfast                                     " for faster redraws etc
    if !has('nvim')
        set ttymouse=xterm2                         " experimental
    endif

    " Always show the signcolumn, otherwise it would shift the text each time
    " diagnostics appear/become resolved: (as per coc recommendation)
    if has("nvim-0.5.0") || has("patch-8.1.1564")
      " Recently vim can merge signcolumn and number column into one
      set signcolumn=number
    else
      set signcolumn=yes
    endif

    set ruler                                       " show current pos at bottom
    set wildignorecase                              " file/path tab completion to case insensitive
    set modelines=0                                 " modelines sets the number of
                                                    " lines at the beginning and end
                                                    " of each file vim checks for
                                                    " initializations. basically
                                                    " for file-specific settings.
    set nomodeline                                  " security
    set lazyredraw                                  " redraw only when need to
    set pastetoggle=<F6>                            " key for toggling paste mode (TODO: move to 'Keybindings' section?)


    if !has('nvim') && !exists("$__REMOTE_SSH")
        set viminfo+=n~/.config/nvim/viminfo  " TODO: this is wrong right, for nvim it's shada (~/.local/share/nvim/shada/main.shada by default)
    endif


    """ In order exiting insert mode in vim-airline/bufferline wouldn't lag that much: {{{
        if !has('nvim') && !has('gui_running')
            set ttimeoutlen=10
            augroup FastEscape
                autocmd!
                au InsertEnter * set timeoutlen=0
                au InsertLeave * set timeoutlen=1000
            augroup END
        endif
    """ }}}


    """ set git editor & automatically close gitcommit nested buffer: {{{
        " note we only define GIT_EDITOR if NVIM_LISTEN_ADDRESS has been set by us
        " for tmux session, in which case its value contains '_userdef_' in it;
        if has('nvim') && match($NVIM_LISTEN_ADDRESS, "_userdef_") != -1
          let $GIT_EDITOR = 'nvr -cc split --remote-wait'
          autocmd FileType gitcommit,gitrebase,gitconfig set bufhidden=delete
        endif
    """ }}}


    " autosave file if window loses focus:
    "au FocusLost * :wa

    " auto-reload vimrc on save:
    autocmd! BufWritePost ~/.config/nvim/init.* nested source ~/.config/nvim/init.vim

    """ Folding {{{
        set foldcolumn=0                            " hide folding column
        set foldmethod=indent                       " folds using indent
        set foldnestmax=10                          " max 10 nested folds
        set foldlevelstart=99                       " folds open by default
    """ }}}

    """ Search and replace {{{
        set gdefault                                " default s//g (global); note adding /g toggles global!
        set incsearch                               " "live"-search, ie incremental search
    """ }}}

    """ Matching {{{
        set matchtime=2                             " time to blink match {}
        set matchpairs+=<:>                         " for ci< or ci>
        set showmatch                               " shows matching bracket when cursor is over
    """ }}}

    """ Return to last edit position when opening files, ie remember last position. {{{
        " note there's also a plugin for remembering last position: https://github.com/farmergreg/vim-lastplace
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
    set nowritebackup
    set noswapfile                                  " disable swapfile
    set updatecount=50                              " update swp after 50chars
    """ Persistent undo. Requires Vim 7.3 {{{
        if has('persistent_undo') && exists("&undodir")
            let &undodir = conf_dir . '/undo/'      " where to store undofiles
            if !isdirectory(&undodir)
                silent execute '!mkdir -p '.&undodir
            endif
            set undofile                            " enable undofile
            set undolevels=300                      " max undos stored
            set undoreload=10000                    " buffer stored undos
        endif
    """ }}}
""" }}}

""" Text formatting {{{
    set textwidth=85
    set colorcolumn=85
    set formatoptions=qrn1j
    set autoindent                                  " preserve indentation
    set smartindent                                 " similar to autoindent, but adds some C syntax stuff
    set backspace=indent,eol,start                  " smart backspace
    set cinkeys-=0#                                 " don't force # indentation
    set ignorecase                                  " by default ignore case
    set nrformats+=alpha                            " incr/decr letters C-a/-x
    set shiftround                                  " be clever with tabs
    set shiftwidth=4                                " size of indent; default 8
    set smartcase                                   " sensitive with uppercase
    set smarttab                                    " tab to 0,4,8 etc.
    set softtabstop=4                               " "tab" feels like <tab>
    set tabstop=4                                   " <TAB> appears 4 spaces wide (but is still an actual tab char)
    set expandtab                                   " no real tabs, ie expand to spaces
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

        " Quickly edit/source .config/nvim/init.vim
        noremap <leader>ve :edit $HOME/.config/nvim/init.vim<CR>
        noremap <leader>vs :source $HOME/.config/nvim/init.vim<CR>

        " Toggle text wrapping
        nmap <silent> <leader>w :set invwrap<CR>:set wrap?<CR>

        " Toggle folding
        nnoremap <silent> <Space> @=(foldlevel('.')?'za':"\<Space>")<CR>
        vnoremap <Space> zf

        " buffer delete fix (fix as in won't exit the window when dropping buffer, eg with NerdTree):
        "nnoremap <leader>q :bp<cr>:bd #<cr>  "old
        nnoremap <leader>q :e #<cr>:bd #<cr>

        " Bubbling (bracket matching)  TODO: what is this?
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

        " Disable annoying ex mode (Q) (note we do have a new mapping for Q below)
        "map Q <nop>

        " This is totally awesome - remap jj to escape in insert mode.
        inoremap jj <Esc>

        " map Backspace to C+6 (ie switch to previous buffer):
        nnoremap <BS> <C-^>

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
        "nnoremap <up> <nop>
        "nnoremap <down> <nop>
        "nnoremap <left> <nop>
        "nnoremap <right> <nop>
        "inoremap <up> <nop>
        "inoremap <down> <nop>
        "inoremap <left> <nop>
        "inoremap <right> <nop>

        " move in insert mode:
        " (disabled now, so c-j/k could be used in YCM list)
        "imap <C-h> <C-o>h
        "imap <C-j> <C-o>j
        "imap <C-k> <C-o>k
        "imap <C-l> <C-o>l

        " avoid typos:
        nnoremap ; :

        " only write file when something changed
        "map :w :update

        " Use CTRL-S for saving, also in Insert mode; make sure your shell is not catching ctrl+s (eg 'stty -ixon' setting for bash to disable)
        noremap <C-S>       :update<CR>
        vnoremap <C-S>      <C-C>:update<CR>
        inoremap <C-S>      <C-O>:update<CR>

        " Go to the middle of the line:
        map gm :call cursor(0, virtcol('$')/2)<CR>

        " Copy to system clipboard (from https://www.reddit.com/r/neovim/comments/3fricd/easiest_way_to_copy_from_neovim_to_system/ctrru3b/)
        vnoremap  <leader>y  "+y
        nnoremap  <leader>Y  "+yg_
        nnoremap  <leader>y  "+y
        nnoremap  <leader>yy  "+yy

        " Paste from system clipboard (from https://www.reddit.com/r/neovim/comments/3fricd/easiest_way_to_copy_from_neovim_to_system/ctrru3b/)
        nnoremap <leader>p "+p
        nnoremap <leader>P "+P
        vnoremap <leader>p "+p
        vnoremap <leader>P "+P

        " Y -> yank from cursor to EOL (instead of same as yy)
        noremap Y y$

        " execute current line in shell and replace it with output from the command:
        noremap Q !!$SHELL<CR>

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
        " tab switching, similar to browser tabs:
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
        nnoremap tn  :tabnext<CR>
        nnoremap tk  :tabprev<CR>
        nnoremap tp  :tabprev<CR>
        nnoremap tl  :tablast<CR>
        nnoremap tt  :tabedit<CR>
        nnoremap tm  :tabm<Space>
        nnoremap td  :tabclose<CR>

        " Move to prev/next tabpage:  (disables moving to top/bottom)
        "nnoremap <S-h> gT
        "nnoremap <S-l> gt

        " copy file name and -path:  TODO, needs refining
        " Mnemonic: Copy File path:
        nnor ,cf :let @*=expand("%:p")<CR>
        " Mnemonic: Yank File path:
        nnor ,yf :let @"=expand("%:p")<CR>
        " Mnemonic: yank File Name:
        nnor ,fn :let @"=expand("%")<CR>
    """ }}}

    " Maps to resizing a window split (Warn: conflict with indentation)
    " tags: window resize window resizing window
    if bufwinnr(1)
        "map <silent> < <C-w><
        map <silent> - <C-W>-
        map <silent> + <C-W>+
        map <silent> <down>  3<C-W>-
        map <silent> <up>    3<C-W>+
        map <silent> <left>  3<C-W><
        map <silent> <right> 3<C-W>>
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

            " TODO: any point for this feature?
            nnoremap <leader>s :call ToggleSyntaxHighlighthing()<CR>
        """ }}}

        """ Highlight characters past 85, toggle with <leader>h
        """ You might want to override this function and its variables with
        """ your own in .vimrc.last which might set for example colorcolumn or
        """ even the textwidth. See https://github.com/timss/vimconf/pull/4 {{{
            let g:overlength_enabled = 0
            highlight OverLength ctermbg=238 guibg=#444444

            function! ToggleOverLength()
                if g:overlength_enabled == 0
                    match OverLength /\%85v.*/
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
            " TODO: what is this one for?
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
                " -- with xclip:
                "vn <C-c> y:call system("xclip -i -selection clipboard", getreg("\""))<CR>:call system("xclip -i", getreg("\""))<CR>
                "no <leader><C-v> :call setreg("\"",system("xclip -o -selection clipboard"))<CR>p
                " -- with xsel:
                "vn <C-c> y:call system("xsel --input --clipboard", getreg("\""))<CR>:call system("xsel --input", getreg("\""))<CR>
                "no <leader><C-v> :call setreg("\"",system("xsel --output --clipboard"))<CR>p
                " -- with copyq:
                vn <C-c> y:call system("copyq add -", getreg("\""))<CR>:call system("copyq select 0")<CR>
                no <leader><C-v> :call system("copyq select 0;copyq paste")<CR>
                "or alternatively, use the registry for paste (untested, unsure how to make this work):
                "no <leader><C-v> :call setreg("\"",system("copyq select 0;copyq paste"))<CR>p
            elseif has('mac')
                vn <C-c> y:call system("pbcopy", getreg("\""))<CR>
                no <leader><C-v> :call setreg("\"",system("pbpaste"))<CR>p
            elseif has('win32')
                vn <C-c> y:call system('"%ProgramFiles(x86)%\CopyQ\copyq.exe" add -', getreg("\""))<CR>:call system('"%ProgramFiles(x86)%\CopyQ\copyq.exe" select 0')<CR>
                no <leader><C-v> :call system("copyq select 0;copyq paste")<CR>  "TODO this bit has not been windowsified yet
            endif
        """ }}}

    """ }}}
