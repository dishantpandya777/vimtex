" vimtex - LaTeX plugin for Vim
"
" Maintainer: Karl Yngve Lervåg
" Email:      karl.yngve@gmail.com
"

function! vimtex#process#new() abort " {{{1
  return deepcopy(s:process)
endfunction

" }}}1
function! vimtex#process#run(cmd, ...) abort " {{{1
  let l:opts = a:0 > 0 ? a:1 : {}
  let l:process = extend(deepcopy(s:process), l:opts)
  let l:process.cmd = a:cmd
  call l:process.run()

  return l:process
endfunction

" }}}1
function! vimtex#process#start(cmd, ...) abort " {{{1
  let l:opts = a:0 > 0 ? a:1 : {}
  let l:process = extend(deepcopy(s:process), l:opts)
  let l:process.cmd = a:cmd
  let l:process.continuous = 1
  call l:process.run()

  return l:process
endfunction

" }}}1

let s:process = {
      \ 'cmd' : '',
      \ 'pid' : 0,
      \ 'background' : 1,
      \ 'continuous' : 0,
      \ 'output' : '',
      \ 'workdir' : '',
      \}

function! s:process.run() abort dict " {{{1
  if self._do_not_run() | return | endif

  call self._pre_run()
  call self._prepare()
  call self._execute()
  call self._restore()
  call self._post_run()
endfunction

" }}}1
function! s:process.stop() abort dict " {{{1
  if !self.pid | return | endif

  let l:cmd = has('win32')
        \ ? 'taskkill /PID ' . self.pid . ' /T /F'
        \ : 'kill ' . self.pid
  silent call system(l:cmd)

  let self.pid = 0
endfunction

" }}}1
function! s:process.pprint_items() abort dict " {{{1
  let l:list = [
        \ ['pid', self.pid ? self.pid : '-'],
        \ ['cmd', self.prepared_cmd],
        \]

  let l:config = {
        \ 'background': self.background,
        \ 'continuous': self.continuous,
        \}
  if !empty(self.output)
    let l:config.output = self.output
  endif
  if !empty(self.workdir)
    let l:config.workdir = self.workdir
  endif

  call add(l:list, ['configuration', l:config])

  return l:list
endfunction

" }}}1

function! s:process._do_not_run() abort dict " {{{1
  if empty(self.cmd)
    call vimtex#echo#warning('Can''t run empty command')
    return 1
  endif
  if self.pid
    call vimtex#echo#warning('Process already running!')
    return 1
  endif

  return 0
endfunction

" }}}1
function! s:process._pre_run() abort dict " {{{1
  if empty(self.output) && self.background
    let self.output = 'null'
  endif

  if !empty(self.workdir)
    let self.save_pwd = getcwd()
    execute 'lcd' fnameescape(self.workdir)
  endif
endfunction

" }}}1
function! s:process._execute() abort dict " {{{1
  if self.background
    silent execute '!' . self.prepared_cmd
    if !has('gui_running')
      redraw!
    endif
  else
    execute '!' . self.prepared_cmd
  endif

  " Capture the pid if relevant
  if has_key(self, 'set_pid') && self.continuous
    call self.set_pid()
  endif
endfunction

" }}}1
function! s:process._post_run() abort dict " {{{1
  if !empty(self.workdir)
    execute 'lcd' fnameescape(self.save_pwd)
  endif
endfunction

" }}}1

if has('win32')
  function! s:process._prepare() abort dict " {{{1
    if &shell !~? 'cmd'
      let self.win32_restore_shell = 1
      let self.win32_saved_shell = [
            \ &shell,
            \ &shellcmdflag,
            \ &shellxquote,
            \ &shellxescape,
            \ &shellquote,
            \ &shellpipe,
            \ &shellredir,
            \ &shellslash
            \]
      set shell& shellcmdflag& shellxquote& shellxescape&
      set shellquote& shellpipe& shellredir& shellslash&
    else
      let self.win32_restore_shell = 0
    endif

    let l:cmd = self.cmd

    if !empty(self.output)
      let l:cmd .= self.output ==# 'null'
            \ ? ' >nul'
            \ : ' >'  . self.output
      let l:cmd = 'cmd /s /c "' . l:cmd . '"'
    else
      let l:cmd = 'cmd /c "' . l:cmd . '"'
    endif

    if self.background
      let l:cmd = 'start /b "' . cmd . '"'
    endif

    let self.prepared_cmd = l:cmd
  endfunction

  " }}}1
  function! s:process._restore() abort dict " {{{1
    if self.win32_restore_shell
      let [   &shell,
            \ &shellcmdflag,
            \ &shellxquote,
            \ &shellxescape,
            \ &shellquote,
            \ &shellpipe,
            \ &shellredir,
            \ &shellslash] = self.win32_saved_shell
    endif
  endfunction

  " }}}1
  function! s:process.get_pid() abort dict " {{{1
    let self.pid = 0
  endfunction

  " }}}1
else
  function! s:process._prepare() abort dict " {{{1
    let l:cmd = self.cmd

    if !empty(self.output)
      let l:cmd .= ' >'
            \ . (self.output ==# 'null' ? '/dev/null' : shellescape(self.output))
            \ . ' 2>&1'
    endif

    if self.background
      let l:cmd .= ' &'
    endif

    let self.prepared_cmd = l:cmd
  endfunction

  " }}}1
  function! s:process._restore() abort dict " {{{1
  endfunction

  " }}}1
  function! s:process.get_pid() abort dict " {{{1
    let self.pid = 0
  endfunction

  " }}}1
endif

" vim: fdm=marker sw=2