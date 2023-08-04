
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

""" Plugin settings & keybinds {{{
    if filereadable(conf_dir . '/init.plugin.conf.vim')
        execute 'source '.conf_dir.'/init.plugin.conf.vim'
    endif
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

