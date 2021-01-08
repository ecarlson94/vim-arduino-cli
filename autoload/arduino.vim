if (exists('g:loaded_arduino_autoload') && g:loaded_arduino_autoload)
    finish
endif
let g:loaded_arduino_autoload = 1
if has('win64') || has('win32') || has('win16')
  echoerr "vim-arduino-cli does not support windows :("
  finish
endif
let s:HERE = resolve(expand('<sfile>:p:h:h'))
let s:OS = substitute(system('uname'), '\n', '', '')
" In neovim, run the shell commands using :terminal to preserve interactivity
if has('nvim')
  let s:TERM = 'botright split | terminal! '
elseif has('terminal')
  " In vim, doing "terminal!" will automatically open in a new split
  let s:TERM = 'terminal! '
else
  " Backwards compatible with old versions of vim
  let s:TERM = '!'
endif

" Initialization {{{1
" Set up all user configuration variables
function! arduino#InitializeConfig() abort
  if !exists('g:arduino_board')
    if exists('g:_cache_arduino_board')
      let g:arduino_board = g:_cache_arduino_board
    else
      let g:arduino_board = 'arduino:avr:uno'
    endif
  endif
  if !exists('g:arduino_programmer')
    if exists('g:_cache_arduino_programmer')
      let g:arduino_programmer = g:_cache_arduino_programmer
    else
      let g:arduino_programmer = 'usbtinyisp'
    endif
  endif
  if !exists('g:arduino_args')
    let g:arduino_args = '--verbose'
  endif
  if !exists('g:arduino_build_path')
    let g:arduino_build_path = '{project_dir}/build'
  endif

  if !exists('g:arduino_use_slime')
    let g:arduino_use_slime = 0
  endif
endfunction

" Caching {{{1
" Load the saved defaults
function! arduino#LoadCache() abort
  let s:cache_dir = exists('$XDG_CACHE_HOME') ? $XDG_CACHE_HOME : $HOME . '/.cache'
  let s:cache = s:cache_dir . '/arduino_cache.vim'
  if filereadable(s:cache)
    exec "source " . s:cache
  endif
endfunction

" Save settings to a source-able cache file
function! arduino#SaveCache() abort
  if !isdirectory(s:cache_dir)
    call mkdir(s:cache_dir, 'p')
  endif
  let lines = []
  call s:CacheLine(lines, 'g:_cache_arduino_board')
  call s:CacheLine(lines, 'g:_cache_arduino_programmer')
  call writefile(lines, s:cache)
endfunction

" Arduino command helpers {{{1
function! arduino#GetArduinoExecutable() abort
  if exists('g:arduino_cmd')
    return g:arduino_cmd
  else
    return 'arduino-cli'
  endif
endfunction

function! arduino#SubstituePath(path) abort
  let l:path = a:path
  let l:path = substitute(l:path, '{file}', expand('%:p'), 'g')
  let l:path = substitute(l:path, '{project_dir}', expand('%:p:h'), 'g')
  return l:path
endfunction

function! arduino#GetBuildPath() abort
  if empty(g:arduino_build_path)
    return ''
  endif
  return arduino#SubstituePath(g:arduino_build_path)
endfunction

function! arduino#GetBoards() abort
  let arduino = arduino#GetArduinoExecutable()
  let cmd = arduino . " board list --format json"

  let addresses = filter(eval(system(cmd)), "exists('v:val.boards')")
  let boards = []
  for address in addresses
    for board in address.board
      board.address = address.address
      board.protocol = address.protocol
      board.protocol_label = address.protocol_label
      call add(boards, board)
    endfor
  endfor
  return boards
endfunction

function! arduino#GetFullyQualifiedBoardNames() abort
  let boards = arduino#GetBoards()
  let fqbns = []
  for board in board
    if index(fqbns, board.FQBN) == -1
      call add(fqbns, board.FQBN)
    endif
  endfor
endfunction

function! arduino#GetProgrammers() abort
  if !exists('g:arduino_board')
    arduino#ChooseBoard()
  endif
  let arduino = arduino#GetArduinoExecutable()
  let cmd = arduino . " board details -b " . g:arduino_board . "  --list-programmers -f --format json"

  let boardDetails = eval(system(cmd))
  let programmers = []
  for programmer in boardDetails.programmers
    if index(programmers, programmer.id) == -1
      call add(programmers, programmer.id)
    endif
  endif
  return sort(programmers)
endfunction

function! s:BoardOrder(b1, b2) abort
  let c1 = split(a:b1, ':')[2]
  let c2 = split(a:b2, ':')[2]
  return c1 == c2 ? 0 : c1 > c2 ? 1 : -1
endfunction

" Port selection {{{2

function! arduino#ChoosePort(...) abort
  if a:0
    let g:arduino_serial_port = a:1
    return
  endif
  let ports = arduino#GetPorts()
  if empty(ports)
    echoerr "No likely serial ports detected!"
  else
    call arduino#Choose('Port', ports, 'arduino#SelectPort')
  endif
endfunction

function! arduino#SelectPort(port) abort
  let g:arduino_serial_port = a:port
endfunction

" Board selection {{{2

" Display a list of boards to the user and allow them to choose the active one
function! arduino#GetActiveBoard() abort
  if !exists('g:arduino_board')
    arduino#ChooseBoard()
  endif
  return g:arduino_board
endfunction

function! arduino#ChooseBoard(...) abort
  if a:0
    call arduino#SetBoard(a:1)
    return
  endif
  let boards = arduino#GetFullyQualifiedBoardNames()
  if empty(boards)
    echoeer "No boards to choose from"
  else
    call sort(boards, 's:BoardOrder')
    call arduino#Choose('Arduino Board', boards, 'arduino#SelectBoard')
  endif
endfunction

" Callback from board selection. Sets the board and prompts for any options
function! arduino#SelectBoard(board) abort
  call arduino#SetBoard(a:board)
endfunction

" Programmer selection {{{2

function! arduino#ChooseProgrammer(...) abort
  if a:0
    call arduino#SetProgrammer(a:1)
    return
  endif
  let programmers = arduino#GetProgrammers()
  call arduino#Choose('Arduino Programmer', programmers, 'arduino#SetProgrammer')
endfunction

function! arduino#SetProgrammer(programmer) abort
  let g:_cache_arduino_programmer = a:programmer
  let g:arduino_programmer = a:programmer
  call arduino#SaveCache()
endfunction

" Command functions {{{2

" Set the active board
function! arduino#SetBoard(board, ...) abort
  let board = a:board
  if a:0
    let options = a:1
    let prevchar = ':'
    for key in keys(options)
      let board = board . prevchar . key . '=' . options[key]
      let prevchar = ','
    endfor
  endif
  let g:arduino_board = a:board
  let g:_cache_arduino_board = board
  call arduino#SaveCache()
endfunction

function! arduino#GetCompileCommand() abort
  let arduino = arduino#GetArduinoExecutable()
  let board = arduino#GetActiveBoard()
  let l:build_path = arduino#GetBuildPath()
  let l:sketch_path = arduino#SubstituePath("{project_dir}")
  let cmd = arduino . " compile -b " . board . ' ' . l:sketch_path . " --build-path " . l:build_path

  let boardParts = split(board, ':')
  let core = boardParts[0] . boardParts[1]
  let installedCores = json_decode(system(arduino . " core list --format json"))
  let requiredCoreInstalled = !empty(filter(installedCores, 'v:val.ID=="'. core . '"'))
  if !requiredCoreInstalled
    cmd = arduino . " core install " . core . " && " . cmd
  endif

  return cmd
endfunction

function! arduino#Compile() abort
  let cmd = arduino#GetCompileCommand()

  if g:arduino_use_slime
    call slime#send(cmd."\r")
  else
    exe s:TERM . cmd
  endif
  return v:shell_error
endfunction

function! arduino#Upload() abort
  let cmd = arduino#GetCompileCommand()
  let port = arduino#GetPort()
  let cmd = cmd . " --upload -p " . port

  if exists('g:arduino_programmer')
    cmd = cmd . " --programmer " . g:arduino_programmer
  endif

  if g:arduino_use_slime
    call slime#send(cmd."\r")
  else
    exe s:TERM . cmd
  endif
  return v:shell_error
endfunction

function! arduino#Attach() abort
  let arduino = arduino#GetArduinoExecutable()
  let board = arduino#GetActiveBoard()
  let cmd = arduino . " board attach " . board

  if g:arduino_use_slime
    call slime#send(cmd."\r")
  else
    exe s:TERM . cmd
  endif
endfunction

function! arduino#UploadAndAttach() abort
  let ret = arduino#Upload()
  if ret == 0
    call arduino#Attach()
  endif
endfunction

" Serial helpers {{{2

function! arduino#GetPorts() abort
  let boards = arduino#GetBoards()
  if emtpy(boards)
    return []
  endif
  let ports = []
  let board = arduino#GetActiveBoard()
  for b in boards
    if b.FQBN == board
      call add(ports, b.address)
    endif
  endfor
  if empty(ports)
    arduino#ChooseBoard()
    arduino#GetPorts()
  else
    return ports
  endif
endfunction

function! arduino#GuessSerialPort() abort
  let ports = arduino#GetPorts()
  if empty(ports)
    return 0
  else
    return ports[0]
  endif
endfunction

function! arduino#GetPort() abort
  if exists('g:arduino_serial_port')
    return g:arduino_serial_port
  else
    return arduino#GuessSerialPort()
  endif
endfunction

"}}}2
" Utility functions {{{1
"
let s:fzf_counter = 0
function! s:fzf_leave(callback, item)
  call function(a:callback)(a:item)
  let s:fzf_counter -= 1
endfunction
function! s:mk_fzf_callback(callback)
  return { item -> s:fzf_leave(a:callback, item) }
endfunction

function! arduino#Choose(title, items, callback) abort
  if g:arduino_ctrlp_enabled
    let ext_data = get(g:ctrlp_ext_vars, s:ctrlp_idx)
    let ext_data.lname = a:title
    let s:ctrlp_list = a:items
    let s:ctrlp_callback = a:callback
    call ctrlp#init(s:ctrlp_id)
  elseif g:arduino_fzf_enabled
    let s:fzf_counter += 1
    call fzf#run({'source':a:items, 'sink':s:mk_fzf_callback(a:callback), 'options':'--prompt="'.a:title.': "'})
    " neovim got a problem with startinsert for the second fzf call, therefore feedkeys("i")
    " see https://github.com/junegunn/fzf/issues/426
    " see https://github.com/junegunn/fzf.vim/issues/21
    if has("nvim") && mode() != "i" && s:fzf_counter > 1
      call feedkeys('i')
    endif
  else
    let labels = ["   " . a:title]
    let idx = 1
    for item in a:items
      if idx<10
        call add(labels, " " . idx . ") " . item)
      else
        call add(labels, idx . ") " . item)
      endif
      let idx += 1
    endfor
    let choice = inputlist(labels)
    if choice > 0
      call call(a:callback, [a:items[choice-1]])
    endif
  endif
endfunction

function! s:CacheLine(lines, varname) abort
  if exists(a:varname)
    let value = eval(a:varname)
    call add(a:lines, 'let ' . a:varname . ' = "' . value . '"')
  endif
endfunction

" Print the current configuration
function! arduino#GetInfo() abort
  let port = arduino#GetPort()
  if empty(port)
      let port = "none"
  endif
  echo "Board          : " . g:arduino_board
  echo "Programmer     : " . g:arduino_programmer
  echo "Port           : " . port
  echo "Compile command: " . arduino#GetCompileCommand()
endfunction

" Ctrlp extension {{{1
if exists('g:ctrlp_ext_vars')
  let g:arduino_ctrlp_enabled = 1
  let s:ctrlp_idx = len(g:ctrlp_ext_vars)
  call add(g:ctrlp_ext_vars, {
    \ 'init': 'arduino#ctrlp_GetData()',
    \ 'accept': 'arduino#ctrlp_Callback',
    \ 'lname': 'arduino',
    \ 'sname': 'arduino',
    \ 'type': 'line',
    \ })

  let s:ctrlp_id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)
else
  let g:arduino_ctrlp_enabled = 0
endif

function! arduino#ctrlp_GetData() abort
  return s:ctrlp_list
endfunction

function! arduino#ctrlp_Callback(mode, str) abort
  call ctrlp#exit()
  call call(s:ctrlp_callback, [a:str])
endfunction

" fzf extension {{{1
if exists("*fzf#run")
  let g:arduino_fzf_enabled = 1
else
  let g:arduino_fzf_enabled = 0
endif

" vim:fen:fdm=marker:fmr={{{,}}}
