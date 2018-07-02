
" We use Vim settings
" TODO: check this out: https://github.com/skwp/dotfiles
" TODO: check out junegunn's vimrc
" quite sure this was the base config:  https://github.com/timss/vimconf/blob/master/.vimrc
"
"
set nocompatible " Must be the first line

""" vim-plug plugin manager {{{
    """ Automatically setting up, taken from
    """ https://github.com/junegunn/vim-plug/wiki/tips#automatic-installation
        let has_plug=1
        if empty(glob('~/.config/nvim/autoload/plug.vim'))
            let has_plug=0
            echo "Installing vim-plug..."
            echo ""
            silent !curl -fLo ~/.config/nvim/autoload/plug.vim --create-dirs
                \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
            autocmd VimEnter * PlugInstall --sync | source $MYVIMRC

            " make directory for the persistent undo storage (not related to vim-plug)...
            silent !mkdir -p $HOME/.config/nvim/undo
            " ...and for tags (used by vim-easytags):
            silent !mkdir -p $HOME/.config/nvim/tags
        endif
    """ }}}

    """ Initialize vim-plug {{{
            call plug#begin('~/.config/nvim/bundle')
    """ }}}

    """ Local plugins (and only plugins in this file!) {{{
        if filereadable($HOME."/.config/nvim/nvim.plugins")
            source $HOME/.config/nvim/nvim.plugins
        endif
    """ }}}

    " Edit files using sudo/su
    "Plug 'chrisbra/SudoEdit.vim'

    " A pretty statusline, bufferline integration:
    "Plug 'itchyny/lightline.vim' "liiga minimalist mu jaoks
    " !! use either vim-airline OR powerline !!
    "   also, pwrline needs to be installed EITHER with vim-plug-manager OR by pip, never /w both
    Plug 'vim-airline/vim-airline'
    Plug 'bling/vim-bufferline'

    " Easy... motions... yeah.
    Plug 'Lokaltog/vim-easymotion'

    " TODO: check out this alternative to easymotion:
    "Plug  'justinmk/vim-sneak'

    " Glorious colorscheme
    "Plug 'nanotech/jellybeans.vim'
    "Plug 'mhinz/vim-janah'  " A dark colorscheme for Vim.
    Plug 'morhetz/gruvbox'

    " Super easy commenting, toggle comments etc
    Plug 'scrooloose/nerdcommenter'

    " Autoclose (, " etc; ie when you insert an (, then ) will be automatically
    " inserted, and cursor placed between them;
    "Plug 'Townk/vim-autoclose'
    " uses delimitMate instead of vim-autoclose, if you use YCM (they conflict):
    Plug 'Raimondi/delimitMate'

    " Git wrapper inside Vim
    Plug 'tpope/vim-fugitive'

    " better git log borwser (hit :gitv)
    " !!! depfnds on tpope/fugitive !!!
    Plug 'gregsexton/gitv'

    " Handle surround chars like ''
    Plug 'tpope/vim-surround'

    " Align your = etc.
    Plug 'vim-scripts/Align'

    " Snippets like textmate
    "Plug 'MarcWeber/vim-addon-mw-utils' "vim-snipmate depends on this one
    "Plug 'tomtom/tlib_vim'              " ... and this.
    Plug 'honza/vim-snippets'           " The snippets repo, and...
    Plug 'SirVer/ultisnips'             "...the engine.

    " A fancy start screen, shows MRU etc:
    Plug 'mhinz/vim-startify'

    " Vim signs (:h signs) for modified lines based off VCS (e.g. Git)
    " for git-only usage, consider vim-gitgutter
    Plug 'mhinz/vim-signify'

    " git-only support similar to vim-signify (only use one of them!)
    "Plug 'airblade/vim-gitgutter'

    " change vim working dir to project root:
    Plug 'airblade/vim-rooter'

    " Awesome syntax checker.
    " REQUIREMENTS: See :h syntastic-intro
    " alternative: neomake
    Plug 'vim-syntastic/syntastic'

    " Functions, class data etc.
    " REQUIREMENTS: (exuberant)-ctags
    "Plug 'majutsushi/tagbar'

    " Ctags generator/highlighter (note the vim-misc is dependency for it)
    Plug 'xolox/vim-misc'
    Plug 'xolox/vim-easytags' " alternative shoud be taginator?
    Plug 'xolox/vim-session'
    "Plug 'xolox/vim-notes'  " alternative: http://orgmode.org/
    Plug 'fmoralesc/vim-pad', { 'branch': 'devel' }   " alt to vim-notes
    Plug 'vim-pandoc/vim-pandoc'  " this and pandoc-syntax for vim-pad
    Plug 'vim-pandoc/vim-pandoc-syntax'
    Plug 'jceb/vim-orgmode'  " text outlining (to use with note-taking plugins?)

    " Selfexplanatory...
    Plug 'jlanzarotta/bufexplorer'

    " File browser
    Plug 'scrooloose/nerdtree', { 'on': ['NERDTreeToggle', 'NERDTreeFind'] }

    " Visualise the undo tree
    Plug 'simnalamburt/vim-mundo', { 'on': 'MundoToggle' }  " gundo fork with neovim support

    " fast mechanism to open files and buffers.
    " requires compiling - read the docs/wiki!
    " perhaps time to deprecate for ctrl-p?
    Plug 'wincent/Command-T'

    " development completion engine (integrates with utilsnips and deprecates
    " supertab et al; needs compilation! read the docs!:
    " !!! ühed väidavad, et javaphp,js,html jaoks on neocomplete parem;
    " for neovim, consider Shougo/deoplete.nvim as alternative;
    Plug 'Valloric/YouCompleteMe'

    " Go-lang/golang/go lang support:
    Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }

    " Scala
    Plug 'derekwyatt/vim-scala'

    " C# support: (requires mono)    https://github.com/OmniSharp/omnisharp-vim
    "Plug 'OmniSharp/omnisharp-vim'  " using one provided by YCM

    " c# additions (mainly better syntax highlight):
    Plug 'OrangeT/vim-csharp'

    " Node.js:
    Plug 'moll/vim-node'

    " js beautifier:
    "Plug 'jsbeautify'

    " navigate seamlessly btw vim & tmux splits (don't forget tmux bindings in
    " .tmux.conf as well):
    Plug 'christoomey/vim-tmux-navigator'

    " supertab: (only so YCM and UltiSnips could play along, otherwise don't need)
    " <Tab> everything!
    Plug 'ervandew/supertab'

    " basically here only so vim-puppet can auto-align rockets:
    "Plug 'godlygeek/tabular'

    " yankring: hold copy of yanked elements:
    " alternative: yankstack
    Plug 'vim-scripts/YankRing.vim'
    "Plug 'maxbrunsfeld/vim-yankstack'

    " show location of the marks: (! requires compilation with +signs)
    " !!! deprecated by vim-signature?
    "Plug 'showmarks'

    " show, place and toggle marks: (! requires compilation with +signs)
    Plug 'kshenoy/vim-signature'

    " camel case movements:
    Plug 'bkad/CamelCaseMotion'

    " typos:
    "Plug 'chip/vim-fat-finger'

    " rainbow parnes:
    "Plug 'kien/rainbow_parentheses.vim'
    Plug 'luochen1990/rainbow'

    " tern for vim (tern is a standalone js analyzer)
    " depends on tern! - https://github.com/ternjs/tern
    " @ .vim/bundle/tern_for_vim:  npm install tern
    "Plug 'ternjs/tern_for_vim'  " using one provided by YCM

    " easy find and replace across multiple files
    " alternative - greplace
    Plug 'dkprice/vim-easygrep'

    " visual-star-search - search words selected in visual mode:
    Plug 'bronson/vim-visual-star-search'

    " front for ag, aka the silver_searcher:
    " depends on the_silver_searcher - apt-get install silversearcher-ag   proj @ ggreer/the_silver_searcher
    Plug 'rking/ag.vim'

    " manipulate on blocks based on their indentation:
    " use  vai  and vii
    Plug 'michaeljsmith/vim-indent-object'

    " provides text-object 'a' (argument) - you can delete, change, select etc in
    " familiar ways;, eg daa, cia,...
    Plug 'vim-scripts/argtextobj.vim'

    " gives 'f' textobj so vaf to select javascript function
    Plug 'thinca/vim-textobj-function-javascript'

    " better jquery syntax highlighting:
    "Plug 'jQuery'

    " TODO: consider  pangloss/vim-javascript  instead
    Plug 'jelera/vim-javascript-syntax'

    " show search window as 'at match # out of # matches':
    Plug 'henrik/vim-indexed-search'

    " tab completion in search:
    Plug 'vim-scripts/SearchComplete' "TODO: currently doesn't work!

    " adds . (repeat) functionality to more complex commands instead of the native-only ones:
    Plug 'tpope/vim-repeat'

    " ends if-blocks etc for few langs:
    Plug 'tpope/vim-endwise'

    " vim sugar for unix shell commands:
    Plug 'tpope/vim-eunuch'

    " async jobs
    Plug 'tpope/vim-dispatch'

    " add :CopyPath and :CopyFileName commands
    Plug 'vim-scripts/copypath.vim'

    " project specific vimrc:   # TODO: works with nvim?
    Plug 'LucHermitte/lh-vim-lib' " dependency for local_vimrc
    Plug 'LucHermitte/local_vimrc'

    " puppet syntax highlight, formatting...
    Plug 'rodjek/vim-puppet'

    " tabline + tab rename
    Plug 'gcmt/taboo.vim'

    " vim multidiff in tabs:
    "Plug 'xenomachina/public/tree/master/vim/plugin'
    " consider targets.vim - adds new text objects

    " open terminal OR file manager at the directory of current location (got, goT, fog, goF)
    Plug 'justinmk/vim-gtfo'

    " universal text linking (here for orgmode hyperlink support) " vim-scripts/utl.vim
    Plug 'vim-scripts/utl.vim'

    Plug 'PotatoesMaster/i3-vim-syntax'

    Plug 'junegunn/fzf.vim'  " https://github.com/junegunn/fzf.vim

    " ctrl+w o   to zoom into a window and back:
    "Plug 'drn/zoomwin-vim'  " TODO: atm only works with vim (not nvim; better use :tab split?)
    set rtp+=~/.fzf  "https://github.com/junegunn/fzf


    " Finish vim-plug stuff
    call plug#end()

    """ Installing plugins the first time; quits when done {{{
        if has_plug == 0
            :silent! PlugInstall
            :qa
        endif
    """ }}}
""" }}}

""" Local leading config, only use for prerequisites as it will be
""" overwritten by anything below {{{
    if filereadable($HOME."/.config/nvim/init.vim.first")
        source $HOME/.config/nvim/init.vim.first
    endif
""" }}}

""" Keybindings {{{
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

        " Gundo/Mundo toggle:
        nnoremap <F5> :MundoToggle<CR>

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
        \ $HOME . "/.config/nvim/init.vim", $HOME . "/.config/nvim/init.vim.first",
        \ $HOME . "/.config/nvim/init.vim.last", $HOME . "/.config/nvim/nvim.plugins"
        \ ]
    let g:startify_custom_header = [
        \ '   Author:               la',
        \ '   Original vimconf:     http://github.com/timss/vimconf',
        \ ''
        \ ]


    " yankring:
    " remap c-p so CtrlP could use it:
    " TODO: think of an actual mappings!:
    let g:yankring_replace_n_pkey = '<leader>p'
    let g:yankring_replace_n_nkey = '<leader>P'
    let g:yankring_history_dir = '$HOME/.config/nvim'
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
    "let g:airline#extensions#tabline#enabled = 1  "when using this, comment out tab colring (doesn't break it, just pointless)

    " bufferline:
    "let g:bufferline_active_buffer_left = '['
    "let g:bufferline_active_buffer_right = ']'
    "let g:bufferline_modified = '+'
    let g:bufferline_show_bufnr = 0
    let g:bufferline_rotate = 1  " scrolling with fixed current buf position
    "let g:bufferline_inactive_highlight = 'StatusLineNC'
    "let g:bufferline_active_highlight = 'StatusLine'
    "let g:bufferline_echo = 1
    let g:bufferline_fixed_index = 0 "always first

    " TagBar
    let g:tagbar_left = 0
    let g:tagbar_width = 30

    " vim-easytags:
    set tags=./.tags;,~/.vimtags
    let g:easytags_dynamic_files = 1 " search for project specific tags; relative to wd or buffer!
    let g:easytags_by_filetype = '~/.config/nvim/tags' " TODO: how to use with jsctags?; also fyi -  dynamic_files takes precedence over this
    let g:easytags_always_enabled = 1
    let g:easytags_on_cursorhold = 1
    let g:easytags_async = 1
    "let g:easytags_include_members = 1
    "let g:easytags_autorecurse = 1 "!!! makes stuff slooooow
    "let g:easytags_events = ['BufWritePost']
    "let g:easytags_languages = {
                "\   'javascript': {
                "\     'cmd': 'jsctags',
                "\       'args': ['-f', '$HOME/.config/nvim/tags/javascript'],
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
    let g:syntastic_bash_checkers = ['shellcheck']
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
    let g:session_directory = '~/.config/nvim/sessions'

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
    let g:notes_directories = ['/data/Seafile/main/notes']
    let g:notes_suffix = '.note'
    let g:notes_indexfile = '/data/Seafile/main/notes/.search_index'  " optional search index for :SearchNotes for accelerated searching
    let g:notes_tagsindex = '/data/Seafile/main/notes/.tags_index'
    let g:notes_conceal_url = 0  " don't conceal URL protocols

    " vim-pad
    let g:pad#dir = '/data/Seafile/main/vim-pad'
    let g:pad#open_in_split = 0  " when set to 0, then opens note in full window, not in split
    let g:pad#window_height = 20  " the bottom split window height
    "let g:pad#default_format = "pandoc"  " default format is markdown; this overrides it
    let g:pad#default_format = "orgmode"  " default format is markdown; this overrides it
    "let g:pad#exclude_dirnames = "img,assets"
    let g:pad#search_backend = 'ag'
    let g:pad#local_dir = '.notes'  " local dir for separate (eg project-specific) set of notes
    let g:pad#default_file_extension = '.org'  " note .org only makes sense when orgmode is used

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

    " nerdtree
    " close vim if the only window left open is nerdtree:
    autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

    " vim-gtfo
    " set shell to open with 'got' keycombo:
    let g:gtfo#terminals = { 'unix' : 'urxvt -cd' }

    " vim-orgmode
    " conceal what can be concealed:
    let g:org_aggressive_conceal = 1
    " indent body text:
    let g:org_indent = 1
""" }}}

""" Local ending config, will overwrite anything above. Generally use this. {{{{
    if filereadable($HOME."/.config/nvim/init.vim.last")
        source $HOME/.config/nvim/init.vim.last
    endif
""" }}}
"
" !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
" !!!!! UNORGANISED STUFF:
" !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

" fzf ripgrep  (from https://github.com/junegunn/fzf.vim)
if executable("rg")
    command! -bang -nargs=* Rg
          \ call fzf#vim#grep(
          \   'rg --column --line-number --no-heading --color=always --ignore-case '.shellescape(<q-args>), 1,
          \   <bang>0 ? fzf#vim#with_preview('up:60%')
          \           : fzf#vim#with_preview('right:50%:hidden', '?'),
          \   <bang>0)

    nnoremap <C-p>a :Rg
endif

