
" We use Vim settings
" TODO: check this out: https://github.com/skwp/dotfiles
" TODO: check out junegunn's vimrc
" quite sure this was the base config:  https://github.com/timss/vimconf/blob/master/.vimrc
" @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
" nice vimrc (and general dotfiles): https://github.com/kshenoy/dotfiles
" also https://dev.to/voyeg3r/my-ever-growing-neovim-init-lua-h0p (lua)
"
"
set nocompatible " Must be the first line

" example of defining&using our own OS-identifying args: {{{
"if !exists('g:os')
"    if has('win32') || has('win16')
"        let g:os = 'Windows'
"    else
"        let g:os = substitute(system('uname'), '\n', '', '')
"    endif
"endif
"
"if g:os == 'Darwin'
"    " do mac stuff
"endif
"
"if g:os == 'Linux'
"    " do linux stuff
"endif
"
"if g:os == 'Windows'
"    " do windows stuff
"endif
" }}}

if has('unix')
    let g:python3_host_prog = '/usr/bin/python3'
    let g:python_host_prog = '/usr/bin/python2'
endif

" disable LSP features in ALE (covered by coc); needs to be set _before_ plugins are loaded!
let g:ale_disable_lsp = 1
let g:ale_virtualtext_cursor = 'current'  " to show the inline errors only on active line

let conf_dir = stdpath('config')

""" vim-plug plugin manager {{{
    """ Automatically setting up, taken from
    """ https://github.com/junegunn/vim-plug/wiki/tips#automatic-installation
        let has_plug=1
        let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
        if empty(glob(data_dir . '/autoload/plug.vim'))
            let has_plug=0
            echo "Installing vim-plug..."
            echo ""
            silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
            autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
        endif

    """ Initialize vim-plug {{{
            call plug#begin()
    """ }}}

    """ Local plugins (and only plugins in this file!) {{{
        if filereadable(conf_dir . '/init.plugins.vim')
            execute 'source '.conf_dir.'/init.plugins.vim'
        endif
    """ }}}


    " Finish vim-plug stuff
            call plug#end()

    """ Installing plugins the first time; quits when done {{{
        if has_plug == 0
            :silent! PlugInstall --sync
            :qa
        endif
    """ }}}
""" }}}

""" Local leading config, only use for prerequisites as it will be
""" overwritten by anything below {{{
    if filereadable(conf_dir . '/init.first.vim')
        execute 'source '.conf_dir.'/init.first.vim'
    endif
""" }}}

""" Keybindings {{{
    """ Plugins {{{
        " Toggle tagbar (definitions, functions etc.)
        map <F1> :TagbarToggle<CR>
        nmap <F8> :TagbarToggle<CR>

        " Syntastic - toggle error list. Probably should be toggleable.
        "noremap <silent><leader>lo :Errors<CR>
        "noremap <silent><leader>lc :lcl<CR>

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

        " CamelCaseMotion: Replace the default 'w', 'b' and 'e' mappings instead of defining additional mappings ',w', ',b' and ',e': ...
        "map <silent> w <Plug>CamelCaseMotion_w
        "map <silent> b <Plug>CamelCaseMotion_b
        "map <silent> e <Plug>CamelCaseMotion_e
        "sunmap w
        "sunmap b
        "sunmap e
        " ...or define the <leader>-motion options (my preferred mappings for this plugin):
        "map <silent><leader> w <Plug>CamelCaseMotion_w
        "map <silent><leader> b <Plug>CamelCaseMotion_b
        "map <silent><leader> e <Plug>CamelCaseMotion_e

        " yankring:
        " toggle yankring window:
        nnoremap <silent> <F11> :YRShow<CR> 

        " FZF stuff
        nnoremap <leader>l :Lines<CR>

    """ }}}
""" }}}

""" Plugin settings {{{
    " use copyq for copy-paste (from https://www.reddit.com/r/neovim/comments/jaw62e/help_needed_on_clipboard/)
    "let g:clipboard = {  
        "\ 'name': 'copyq',  
        "\ 'copy': {  
        "\    '+': ['copyq', 'add', '-'],
        "\    '*': ['copyq', 'add', '-'],
        "\ },
        ""\ 'paste': {  
        ""\    '+': ['copyq', 'paste'],
        ""\    '*': ['copyq', 'paste'],
        ""\ },
        ""\ 'paste': {
        ""\    '+': ['+'],
        ""\    '*': ['*'],
        ""\ },
        "\ 'cache_enabled': 0,
        "\ }

    " use tmux buffers instead:
    "let g:clipboard = {
          "\   'name': 'myClipboard',
          "\   'copy': {
          "\      '+': 'tmux load-buffer -',
          "\      '*': 'tmux load-buffer -',
          "\    },
          "\   'paste': {
          "\      '+': 'tmux save-buffer -',
          "\      '*': 'tmux save-buffer -',
          "\   },
          "\   'cache_enabled': 1,
          "\ }

    " Startify, the fancy start page
    let g:startify_bookmarks = [
        \ $HOME . "/.config/nvim/init.vim", $HOME . "/.config/nvim/init.first.vim",
        \ $HOME . "/.config/nvim/init.last.vim", $HOME . "/.config/nvim/init.plugins.vim"
        \ ]
    let g:startify_custom_header = [
        \ '   Author:               LA',
        \ '   Original vimconf:     http://github.com/timss/vimconf',
        \ ''
        \ ]


    " yankring:
    " remap c-p so CtrlP/fzf could use it:
    " TODO: think of an actual mappings!:
    " TODO: leader+{p,P} conflict with our other pasting mappings!!!
    let g:yankring_replace_n_pkey = '<leader>p'
    let g:yankring_replace_n_nkey = '<leader>P'
    let g:yankring_history_dir = conf_dir
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
    let g:airline#extensions#bufferline#enabled = 1
    "let g:airline#extensions#bufferline#overwrite_variables = 1
    let g:airline#extensions#tabline#enabled = 1  "when using this, comment out tab colring (doesn't break it, just pointless)
    let g:airline#extensions#coc#enabled = 1

    " vim-bufferline:
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

    " gutentags
    "set tags=./.tags;,~/.vimtags   <-- TODO: does gutentags use this one? vim-easytags did, this not so sure
    set statusline+=%{gutentags#statusline()}  " show when we're generating tags
    "let g:gutentags_trace=1  " debug
    "let g:gutentags_cache_dir = '~/.cache/gutentags'  " if we want to store all tags in central location, not at root of projects
    let g:gutentags_ctags_tagfile = '.tags'
    let g:gutentags_resolve_symlinks=0
    let g:gutentags_project_root = ['.root_marker']  " user-defined list of markers, in addition to list of default ones
    let g:gutentags_file_list_command = {
        \ 'markers': {
            \ '.git': 'git ls-files',
            \ '.hg': 'hg files',
            \ },
        \ }

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
        " make YCM compatible with UltiSnips (note no longer using supertab!):
        let g:ycm_key_list_select_completion = ['<C-j>', '<Down>']
        let g:ycm_key_list_previous_completion = ['<C-k>', '<Up>']
        "let g:SuperTabDefaultCompletionType = '<C-j>' "enables us to use tab to cycle through non-ultisnip items

        " better key bindings for UltiSnipsExpandTrigger ('tab' is generally used, but it tends to collide w/ other plugins)
        "let g:UltiSnipsExpandTrigger = "<tab>"
        "let g:UltiSnipsJumpForwardTrigger = "<tab>"
        "let g:UltiSnipsJumpBackwardTrigger = "<s-tab>"
        " alternative to the previous:
        let g:UltiSnipsExpandTrigger="<c-j>"
        let g:UltiSnipsJumpForwardTrigger="<c-j>"
        let g:UltiSnipsJumpBackwardTrigger="<c-k>"

        " How you want :UltiSnipsEdit to split your window:
        let g:UltiSnipsEditSplit="vertical"
    """ }}}  /ultisnips-YCM

    """ coc {{{
        " Use tab for trigger completion with characters ahead and navigate.
        " NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
        " other plugin before putting this into your config.
        inoremap <silent><expr> <TAB>
              \ coc#pum#visible() ? coc#pum#next(1):
              \ CheckBackspace() ? "\<Tab>" :
              \ coc#refresh()
        inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"

        " Make <CR> to accept selected completion item or notify coc.nvim to format
        " <C-g>u breaks current undo, please make your own choice.
        inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm()
                                      \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

        function! CheckBackspace() abort
          let col = col('.') - 1
          return !col || getline('.')[col - 1]  =~# '\s'
        endfunction

        " Use <c-space> to trigger completion.
        if has('nvim')
          inoremap <silent><expr> <c-space> coc#refresh()
        else
          inoremap <silent><expr> <c-@> coc#refresh()
        endif


        " Use K to show documentation in preview window:
        " (!! possibly conflicts w/ default vim-iced shortcut !!)
        "nnoremap <silent> K :call ShowDocumentation()<CR>
        
        function! ShowDocumentation()
          if CocAction('hasProvider', 'hover')
            call CocActionAsync('doHover')
          else
            call feedkeys('K', 'in')
          endif
        endfunction

        " Highlight the symbol and its references when holding the cursor.
        autocmd CursorHold * silent call CocActionAsync('highlight')

        " because of our system nvm hack, manually set node path so _a_ node version is discoverable at a constant location:
        let g:coc_node_path = $NODE_LOC
        "set runtimepath^=/home/laur/dev/coc-clojure  " test local coc extensions/plugins

        " Remap <C-f> and <C-b> for scroll float windows/popups:
        if has('nvim-0.4.0') || has('patch-8.2.0750')
          nnoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? coc#float#scroll(1) : "\<C-f>"
          nnoremap <silent><nowait><expr> <C-b> coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-b>"
          inoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(1)\<cr>" : "\<Right>"
          inoremap <silent><nowait><expr> <C-b> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(0)\<cr>" : "\<Left>"
          vnoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? coc#float#scroll(1) : "\<C-f>"
          vnoremap <silent><nowait><expr> <C-b> coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-b>"
        endif

        " Add (Neo)Vim's native statusline support
        " NOTE: Please see `:h coc-status` for integrations with external plugins that
        " provide custom statusline: lightline.vim, vim-airline
        "set statusline^=%{coc#status()}%{get(b:,'coc_current_function','')}
    """ }}}  /coc


    " vim-tmux-navigator:
    let g:tmux_navigator_no_mappings = 1
    let g:tmux_navigator_save_on_switch = 1

    " YouCompleteMe/YCM:
    " open default ycm_extra_conf, so every project doesn't request
    " explicitly its own:
    "let g:ycm_global_ycm_extra_conf = '~/.ycm_extra_conf.py'

    " Removes YCM's syntax checking for C-family languages, as it breaks the
    " syntastic's syntax checker:
    let g:ycm_show_diagnostics_ui = 0



    " Syntastic - This is largely up to your own usage, and override these
    "             changes if be needed. This is merely an exemplification. {{{
    "let g:syntastic_check_on_open = 1
    "let g:syntastic_enable_signs = 1

    "let g:syntastic_c_checkers = ['gcc']
    "let g:syntastic_c_check_header = 1
    "let g:syntastic_c_auto_refresh_includes = 1

    "let g:syntastic_python_checkers = ['flake8', 'python']
    "let g:syntastic_bash_checkers = ['shellcheck']
    "let g:syntastic_sh_checkers = ['shellcheck', 'checkbashisms']
    "let g:syntastic_javascript_checkers = ['jshint']
    "let g:syntastic_css_checkers = ['csslint']

    "let g:syntastic_cpp_check_header = 1
    ""let g:syntastic_cpp_compiler_options = ' -std=c++0x'
    ""
    "" note go in passive list, as vim-go is installed;
    "let g:syntastic_mode_map = {
        "\ 'mode': 'active',
        "\ 'passive_filetypes':
            "\ ['java','go'] }

    ""let g:syntastic_mode_map = {
        ""\ 'mode': 'passive',
        ""\ 'active_filetypes':
            ""\ ['c', 'cpp', 'perl', 'python'] }

    ""let g:syntastic_mode_map = {
        ""\ 'mode': 'passive',
        ""\ 'active_filetypes': [],
        ""\ 'passive_filetypes': [] } 
    """ }}}


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

    " Automatically remove preview window after autocomplete (mainly for clang_complete)
    augroup RemovePreview
        autocmd!
        autocmd CursorMovedI * if pumvisible() == 0|pclose|endif
        autocmd InsertLeave * if pumvisible() == 0|pclose|endif
    augroup END

    " vim-slash:
    if has('timers')
        " place current match at the center of window (ie zz upon search), AND
        " blink x times with 50ms interval:
        noremap <expr> <plug>(slash-after) 'zz'.slash#blink(3, 50)
    endif

    " vim-notes
    let g:notes_directories = ['/data/Seafile/main/notes']
    let g:notes_suffix = '.note'
    let g:notes_indexfile = '/data/Seafile/main/notes/.search_index'  " optional search index for :SearchNotes for accelerated searching; note this file grows huge!
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

    " vim-easygrep
    let g:EasyGrepRoot="search:.git,.svn,.hg,.ctrlp"
    let g:EasyGrepCommand='ag'
    let g:EasyGrepWindow=0  " 0 -quickfix; 1 -location list
    "let g:EasyGrepWindowPosition="botleft lopen"
    let g:EasyGrepOpenWindowOnMatch=0
    let g:EasyGrepRecursive=1
    let g:EasyGrepMode=2  "search for files that are of a similar type to the current file

    " nerdtree
    " close vim if the only window left open is nerdtree:
    autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
    let NERDTreeAutoDeleteBuffer = 1  " automatically delete buffer of file you just deleted;
    "let NERDTreeQuitOnOpen = 1  " automatically close nerdtree after opening a file with it;

    " vim-gtfo
    " set shell to open with 'got' keycombo:
    let g:gtfo#terminals = { 'unix' : 'urxvtc -cd' }

    " vim-orgmode
    " conceal what can be concealed:
    let g:org_aggressive_conceal = 1
    " indent body text:
    let g:org_indent = 1

    " vim-rooter
    " stop echoing project root dir:
    let g:rooter_silent_chdir = 1
    " resolve symlinks:
    let g:rooter_resolve_links = 1
    " change to file's dir if we're dealing w/ non-project file (similar to autochdir):
    let g:rooter_change_directory_for_non_project_files = 'current'

    " vim-iced
    " Enable vim-iced's default key mapping
    " This is recommended for newbies
    let g:iced_enable_default_key_mappings = v:true
    " display one-line docstring to the right of the line; value is which vim mode this should work in: normal/insert/every
    "let g:iced_enable_auto_document = 'normal'
    " automatically format on file write:
    aug VimIcedAutoFormatOnWriting
      au!
      " Format whole buffer on writing files:
      au BufWritePre *.clj,*.cljs,*.cljc,*.edn execute ':IcedFormatSyncAll'
    
      " Format only current form on writing files:
      " au BufWritePre *.clj,*.cljs,*.cljc,*.edn execute ':IcedFormatSync'
    aug END
    
    " vim-sexp
    " use vim-iced formatting function: (from https://liquidz.github.io/vim-iced/#formatting)
    let g:sexp_mappings = {'sexp_indent': '', 'sexp_indent_top': ''}
""" }}}

""" Local ending config, will overwrite anything above. Generally use this. {{{
    if filereadable(conf_dir . '/init.last.vim')
        execute 'source '.conf_dir.'/init.last.vim'
    endif
""" }}}

" save fold states
"autocmd BufWinLeave *.* mkview
"autocmd BufWinEnter *.* silent loadview
"
" !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
" !!!!! UNORGANISED STUFF:
" !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

" fzf ripgrep  (from https://github.com/junegunn/fzf.vim)
"   :Rg  - Start fzf with ~hidden~ preview window that can be toggled with "?" key
"   :Rg! - Start fzf in fullscreen and display the preview window above
if executable("rg")
    command! -bang -nargs=* Rg
          \ call fzf#vim#grep(
          \   'rg --column --line-number --no-heading --hidden --follow --color=always --smart-case -- '.shellescape(<q-args>), 1,
          \   <bang>0 ? fzf#vim#with_preview('up:60%')
          \           : fzf#vim#with_preview('right:50%', '?'),
          \   <bang>0)


    " define new RG command where the input in fzf is the input to rg - every time you change it, rg process is re-invoked;
    " this also mean in this mode fzf is a dummy selector, not a fuzzy finder itself:
    function! RipgrepFzf(query, fullscreen)
      let command_fmt = 'rg --column --line-number --no-heading --color=always --smart-case -- %s || true'
      let initial_command = printf(command_fmt, shellescape(a:query))
      let reload_command = printf(command_fmt, '{q}')
      let spec = {'options': ['--phony', '--query', a:query, '--bind', 'change:reload:'.reload_command]}
      call fzf#vim#grep(initial_command, 1, fzf#vim#with_preview(spec), a:fullscreen)
    endfunction
    command! -nargs=* -bang RG call RipgrepFzf(<q-args>, <bang>0)


    " this one will define command used by  :grep
    set grepprg=rg\ --vimgrep\ --no-heading
endif

nnoremap <C-P> :Buffers<CR>
nnoremap <leader><C-P> :Files<CR>

" Likewise, Files command with preview window:
command! -bang -nargs=? -complete=dir Files
    \ call fzf#vim#files(<q-args>, fzf#vim#with_preview(), <bang>0)
" same as previous 'Files' definition, but with spec dictionary:
"command! -bang -nargs=? -complete=dir Files
    "\ call fzf#vim#files(<q-args>, fzf#vim#with_preview({'options': ['--layout=reverse', '--info=inline']}), <bang>0)

" git-grep wrapper (again, from fzf.vim readme); defines GGrep command:
command! -bang -nargs=* GGrep
  \ call fzf#vim#grep(
  \   'git grep --line-number -- '.shellescape(<q-args>), 0,
  \   fzf#vim#with_preview({'dir': systemlist('git rev-parse --show-toplevel')[0]}), <bang>0)


""" automatically close terminal {{{
"     close :term automatically, do not show 'process exited 0' message; from https://vi.stackexchange.com/a/17388
"     TODO: should/could be removed once https://github.com/neovim/neovim/issues/4713 is implemented

" Get the exit status from a terminal buffer by looking for a line near the end
" of the buffer with the format, '[Process exited ?]'.
func! s:getExitStatus() abort
  let ln = line('$')
  " The terminal buffer includes several empty lines after the 'Process exited'
  " line that need to be skipped over.
  while ln >= 1
    let l = getline(ln)
    let ln -= 1
    let exitCode = substitute(l, '^\[Process exited \([0-9]\+\)\]$', '\1', '')
    if l != '' && l == exitCode
      " The pattern did not match, and the line was not empty. It looks like
      " there is no process exit message in this buffer.
      break
    elseif exitCode != ''
      return str2nr(exitCode)
    endif
  endwhile
  throw 'Could not determine exit status for buffer, ' . expand('%')
endfunc

func! s:afterTermClose() abort
  if s:getExitStatus() == 0
    bdelete!
  endif
endfunc

augroup MyNeoterm
  autocmd!
  " The line '[Process exited ?]' is appended to the terminal buffer after the
  " `TermClose` event. So we use a timer to wait a few milliseconds to read the
  " exit status. Setting the timer to 0 or 1 ms is not sufficient; 20 ms seems
  " to work for me.
  "autocmd TermClose * call timer_start(20, { -> s:afterTermClose() })
  autocmd TermClose *:$SHELL call timer_start(20, { -> s:afterTermClose() })
augroup END
""" }}}

