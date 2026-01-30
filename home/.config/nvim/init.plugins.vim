" vim: set ft=vimrc:

" Edit files using sudo/su
"Plug 'chrisbra/SudoEdit.vim'  This one does not support neovim! (last commit '23)
Plug 'lambdalisue/vim-suda'

" A pretty statusline, bufferline integration:
"Plug 'itchyny/lightline.vim'  " too minimalist for me
Plug 'vim-airline/vim-airline'
"Plug 'bling/vim-bufferline'

" Easy... motions... yeah.
Plug 'easymotion/vim-easymotion'
" TODO: check out this alternative to easymotion:
"Plug  'justinmk/vim-sneak'

" extend fFtT to be repeatable:
Plug 'rhysd/clever-f.vim'

" Glorious colorscheme
"Plug 'nanotech/jellybeans.vim'
"Plug 'mhinz/vim-janah'  " A dark colorscheme for Vim.
Plug 'morhetz/gruvbox'  " TODO: consider changing to gruvbox-community/gruvbox

" Super easy commenting, toggle comments etc
Plug 'preservim/nerdcommenter'
" see also https://github.com/tomtom/tcomment_vim

" Autoclose (, " etc; ie when you insert an (, then ) will be automatically
" inserted, and cursor placed between them;
" TODO: does it conflict with tpope/vim-endwise?
Plug 'Raimondi/delimitMate'

" Git wrapper inside Vim
Plug 'tpope/vim-fugitive'

" git branch viewer that integrates (and requires!) w/ vim-fugitive
Plug 'rbong/vim-flog'

" Handle surround chars like ''
Plug 'tpope/vim-surround'

" Align your = etc.
Plug 'vim-scripts/Align'  " see also lion
" TODO: start using this instead:
"Plug 'junegunn/vim-easy-align'    

" basically here only so vim-puppet can auto-align rockets:
"Plug 'godlygeek/tabular'

" Snippets like textmate
"Plug 'MarcWeber/vim-addon-mw-utils' "vim-snipmate depends on this one
"Plug 'tomtom/tlib_vim'              " ... and this.
Plug 'honza/vim-snippets'           " The snippets repo, and...
"Plug 'SirVer/ultisnips'             "...the engine. note with coc-snippets this is not needed

" A fancy start screen, shows MRU etc:
"Plug 'mhinz/vim-startify'

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
"Plug 'vim-syntastic/syntastic'

" Async Lint Engine - provies linting
" note if using ale together w/ coc, then it requires additional config on both part;
" see https://github.com/dense-analysis/ale#5iii-how-can-i-use-ale-and-cocnvim-together
"Plug 'dense-analysis/ale'

" Functions, class data etc.
" REQUIREMENTS: (exuberant)-ctags
Plug 'preservim/tagbar'

" Ctags generator/highlighter
Plug 'ludovicchabant/vim-gutentags'  " last commit in '23

"Plug 'xolox/vim-misc'  " remove once we no longer use any of xolox' plugins that use vim-misc as dependency
"Plug 'xolox/vim-session'  " TODO: replace with tpope/vim-obsession?
"Plug 'xolox/vim-notes'  " alternative: http://orgmode.org/
"Plug 'fmoralesc/vim-pad', { 'branch': 'devel' }   " alt to vim-notes
"Plug 'vim-pandoc/vim-pandoc'  " this and pandoc-syntax for vim-pad
"Plug 'vim-pandoc/vim-pandoc-syntax'
Plug 'jceb/vim-orgmode'  " text outlining (to use with note-taking plugins?); see also https://github.com/nvim-orgmode/orgmode !<-- yes, nvim-orgmode is what we want to use instead
" !!!! TODO: there's also https://github.com/nvim-neorg/neorg ;  how does it compare to orgmode? does this have roam alternative as org-roam?
" note there seems to be some work done for org-roam alternative for neo-org: https://github.com/chipsenkbeil/org-roam.nvim
" TODO: consdier also https://github.com/ranjithshegde/orgWiki.nvim as companion to orgmode?
" also https://github.com/zk-org/zk

" Selfexplanatory...
"Plug 'jlanzarotta/bufexplorer'

" File browser
" TODO: alternatives:
" - https://github.com/nvim-neo-tree/neo-tree.nvim
" - https://github.com/nvim-tree/nvim-tree.lua  <-- !!!
" - https://github.com/lambdalisue/vim-fern
Plug 'preservim/nerdtree', { 'on': ['NERDTreeToggle', 'NERDTreeFind'] }

" Visualise the undo tree
Plug 'simnalamburt/vim-mundo', { 'on': 'MundoToggle' }  " gundo fork with neovim support

" fast mechanism to open files and buffers.
" requires compiling - read the docs/wiki! (think ruby support is paramount)
" disabled atm as we're using FZF mainly now
"Plug 'wincent/Command-T'

" development completion engine (integrates with utilsnips and deprecates
" supertab et al; needs compilation! read the docs!):
" !!! ühed väidavad, et javaphp,js,html jaoks on neocomplete parem;
" for neovim, consider Shougo/deoplete.nvim as alternative;
" another alternative: coc (sic)
"Plug 'ycm-core/YouCompleteMe'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
" another alternative: nvim-cmp

" Go-lang/golang/go lang support:
" (believe it's redundtant when using vim-coc)
"Plug 'fatih/vim-go', { 'for': 'go', 'do': ':GoUpdateBinaries' }

" Clojure:
" vim-iced & its deps+extensions+integrations:
Plug 'guns/vim-sexp',    {'for': 'clojure'}
Plug 'liquidz/vim-iced', {'for': 'clojure'}
" add coc support for vim-iced:
Plug 'liquidz/vim-iced-coc-source', {'for': 'clojure'}

" Scala
" TODO: delete? is coc deprecating this?
Plug 'derekwyatt/vim-scala', { 'for': 'scala' }

" C# support: (requires mono)    https://github.com/OmniSharp/omnisharp-vim
"Plug 'OmniSharp/omnisharp-vim'  " using one provided by YCM

" navigate seamlessly btw vim & tmux splits (don't forget tmux plugin or bindings in .tmux.conf as well):
" TODO: see also https://github.com/mrjones2014/smart-splits.nvim
"   - see this for comparison: https://github.com/mrjones2014/smart-splits.nvim/discussions/420#discussioncomment-15562791
Plug 'christoomey/vim-tmux-navigator'

" yankring: hold copy of yanked elements:
" alternative: yankstack
"Plug 'maxbrunsfeld/vim-yankstack'
Plug 'vim-scripts/YankRing.vim'
" another alternative: https://github.com/bfredl/nvim-miniyank

" show, place and toggle marks: (! requires compilation with +signs)
Plug 'kshenoy/vim-signature'

" camel case movements:
"Plug 'bkad/CamelCaseMotion'  " TODO not configured

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

" nicer in-buffer search with *; also clears highlight on cursor move
" another alternative: https://github.com/pgdouyon/vim-evanesco
Plug 'junegunn/vim-slash'

" manipulate on blocks based on their indentation:
" use  vai  and vii
Plug 'michaeljsmith/vim-indent-object'

" provides text-object 'a' (argument) - you can delete, change, select etc in
" familiar ways;, eg daa, cia,...
" TODO: deprecate?
Plug 'vim-scripts/argtextobj.vim'

" Node.js:
" TODO: is this needed?
Plug 'moll/vim-node'

" syntax highlight for vue components:  " https://github.com/posva/vim-vue
" TODO: not actively maintained, find replacement (some linked in project readme)
Plug 'posva/vim-vue', { 'for': 'vue' }

" syntax highlight for 'just' files:  " https://github.com/NoahTheDuke/vim-just
Plug 'NoahTheDuke/vim-just'

" js beautifier:
"Plug 'jsbeautify'

" typescript syntax https://github.com/leafgarland/typescript-vim
" TODO: not really updated anymore, consider replacing w/ https://github.com/tree-sitter/tree-sitter-typescript
"       in general tree-sitter should be prefered for syntax highlighting
Plug 'leafgarland/typescript-vim', { 'for': 'ts' }

" js syntax highlighting & improved indentation:
Plug 'pangloss/vim-javascript'

" tridactyl syntax
Plug 'tridactyl/vim-tridactyl'

" vim syntax for neomuttrc
Plug 'neomutt/neomutt.vim'

" show search window as 'at match # out of # matches':
" looks like now supported natively by vim/nvim? see 'set shortmess-=S' conifg
" !! also - looks like this plugin overrides junegunn/vim-slash
"Plug 'henrik/vim-indexed-search'

" adds . (repeat) functionality to more complex commands instead of the native-only ones:
Plug 'tpope/vim-repeat'

" ends if-blocks etc for few langs:
" TODO: does it conflict with delimitMate plugin?
Plug 'tpope/vim-endwise'

" vim sugar for unix shell commands:
Plug 'tpope/vim-eunuch'

" async jobs
Plug 'tpope/vim-dispatch' " alt: skywind3000/asyncrun.vim

" sessions
Plug 'tpope/vim-obsession'

" project specific vimrc:   # TODO: works with nvim?
Plug 'LucHermitte/lh-vim-lib' " dependency for local_vimrc
Plug 'LucHermitte/local_vimrc'

" puppet syntax highlight, formatting...
Plug 'rodjek/vim-puppet'

" tabline + tab rename
"Plug 'gcmt/taboo.vim'

" vim multidiff in tabs:
"Plug 'xenomachina/public/tree/master/vim/plugin'
" consider targets.vim - adds new text objects

" open terminal OR file manager at the directory of current location (got, goT, fog, goF)
Plug 'justinmk/vim-gtfo'

" https://github.com/vimlab/split-term.vim
" provides us with plenty good mappings, like :Term, :VTerm, :TTerm...
" perhaps see also kassio/neoterm  (this one mostly for REPL)
" also mhinz/neovim-remote
Plug 'vimlab/split-term.vim'

" universal text linking (here for orgmode hyperlink support) " vim-scripts/utl.vim
Plug 'vim-scripts/utl.vim'

" i3 config syntax highlighting:
Plug 'mboughaba/i3config.vim'

" reopen file at last edit position
Plug 'farmergreg/vim-lastplace'

" aider (AI coding tool) plugin: (note there are others)
"Plug 'joshuavial/aider.nvim'

" TODO: consider repacing our own Rg command w/ something like telescope plugin!
"       another alternative to fzf & telescope: https://github.com/liuchengxu/vim-clap (rust)
"       looks like clap&telescope have some overlap: https://github.com/nvim-telescope/telescope.nvim/issues/121
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" plugins to consider once we migrate config over to lua:
" - https://github.com/LintaoAmons/bookmarks.nvim
" - https://github.com/sphamba/smear-cursor.nvim
" - https://github.com/jpalardy/vim-slime - REPL
" - https://github.com/2KAbhishek/seeker.nvim - progressive file seeker
" - https://github.com/alker0/chezmoi.vim - syntax highlighting with [chezmoi edit]
