" function! rust_wrap#PushCursor() {{{2
"
" Adds the current cursor position to the cursor stack.
function! rust_wrap#PushCursor()
  if !exists('b:cursor_position_stack')
    let b:cursor_position_stack = []
  endif

  call add(b:cursor_position_stack, winsaveview())
endfunction

" function! rust_wrap#PopCursor() {{{2
"
" Restores the cursor to the latest position in the cursor stack, as added
" from the rust_wrap#PushCursor function. Removes the position from the stack.
function! rust_wrap#PopCursor()
  call winrestview(remove(b:cursor_position_stack, -1))
endfunction

" function! rust_wrap#SearchSkip(pattern, skip, ...) {{{2
" A partial replacement to search() that consults a skip pattern when
" performing a search, just like searchpair().
"
" Note that it doesn't accept the "n" and "c" flags due to implementation
" difficulties.
function! rust_wrap#SearchSkip(pattern, skip, ...)
  " collect all of our arguments
  let pattern = a:pattern
  let skip    = a:skip

  if a:0 >= 1
    let flags = a:1
  else
    let flags = ''
  endif

  if stridx(flags, 'n') > -1
    echoerr "Doesn't work with 'n' flag, was given: ".flags
    return
  endif

  let stopline = (a:0 >= 2) ? a:2 : 0
  let timeout  = (a:0 >= 3) ? a:3 : 0

  " just delegate to search() directly if no skip expression was given
  if skip == ''
    return search(pattern, flags, stopline, timeout)
  endif

  " search for the pattern, skipping a match if necessary
  let skip_match = 1
  while skip_match
    let match = search(pattern, flags, stopline, timeout)

    " remove 'c' flag for any run after the first
    let flags = substitute(flags, 'c', '', 'g')

    if match && eval(skip)
      let skip_match = 1
    else
      let skip_match = 0
    endif
  endwhile

  return match
endfunction

function! rust_wrap#SkipSyntax(syntax_groups)
  let syntax_groups = a:syntax_groups
  let skip_pattern  = '\%('.join(syntax_groups, '\|').'\)'

  return "synIDattr(synID(line('.'),col('.'),1),'name') =~ '".skip_pattern."'"
endfunction

" function! rust_wrap#Keeppatterns(command) {{{2
"
" Executes the given command, but attempts to keep search patterns as they
" were.
"
function! rust_wrap#Keeppatterns(command)
  if exists(':keeppatterns')
    exe 'keeppatterns '.a:command
  else
    let histnr = histnr('search')

    exe a:command

    if histnr != histnr('search')
      call histdel('search', -1)
      let @/ = histget('search', -1)
    endif
  endif
endfunction

" Surprisingly, Vim doesn't seem to have a "trim" function. In any case, these
" should be fairly obvious.
function! rust_wrap#Ltrim(s)
  return substitute(a:s, '^\_s\+', '', '')
endfunction
function! rust_wrap#Rtrim(s)
  return substitute(a:s, '\_s\+$', '', '')
endfunction
function! rust_wrap#Trim(s)
  return rust_wrap#Rtrim(rust_wrap#Ltrim(a:s))
endfunction

" function! rust_wrap#GetMotion(motion) {{{2
"
" Execute the normal mode motion "motion" and return the text it marks.
"
" Note that the motion needs to include a visual mode key, like "V", "v" or
" "gv"
function! rust_wrap#GetMotion(motion)
  call rust_wrap#PushCursor()

  let saved_register_text = getreg('z', 1)
  let saved_register_type = getregtype('z')

  let @z = ''
  exec 'silent normal! '.a:motion.'"zy'
  let text = @z

  if text == ''
    " nothing got selected, so we might still be in visual mode
    exe "normal! \<esc>"
  endif

  call setreg('z', saved_register_text, saved_register_type)
  call rust_wrap#PopCursor()

  return text
endfunction

" function! rust_wrap#ReplaceMotion(motion, text) {{{2
"
" Replace the normal mode "motion" with "text". This is mostly just a wrapper
" for a normal! command with a paste, but doesn't pollute any registers.
"
"   Examples:
"     call rust_wrap#ReplaceMotion('Va{', 'some text')
"     call rust_wrap#ReplaceMotion('V', 'replacement line')
"
" Note that the motion needs to include a visual mode key, like "V", "v" or
" "gv"
function! rust_wrap#ReplaceMotion(motion, text)
  " reset clipboard to avoid problems with 'unnamed' and 'autoselect'
  let saved_clipboard = &clipboard
  set clipboard=

  let saved_register_text = getreg('"', 1)
  let saved_register_type = getregtype('"')

  call setreg('"', a:text, 'v')
  exec 'silent normal! '.a:motion.'p'
  silent normal! gv=

  call setreg('"', saved_register_text, saved_register_type)
  let &clipboard = saved_clipboard
endfunction

" function! rust_wrap#ReplaceLines(start, end, text) {{{2
"
" Replace the area defined by the 'start' and 'end' lines with 'text'.
function! rust_wrap#ReplaceLines(start, end, text)
  let interval = a:end - a:start

  if interval == 0
    return rust_wrap#ReplaceMotion(a:start.'GV', a:text)
  else
    return rust_wrap#ReplaceMotion(a:start.'GV'.interval.'j', a:text)
  endif
endfunction
