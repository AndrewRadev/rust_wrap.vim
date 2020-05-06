let s:wrap_types = ['Result', 'Option', 'Rc']

command! -buffer -complete=customlist,s:WrapComplete -nargs=+
      \ Wrap call s:Wrap(<f-args>)

" TODO (2020-04-11) Unwrap

function! s:Wrap(type, ...)
  let wrap_type = a:type

  if wrap_type == 'Result'
    " TODO (2020-04-11) custom error type
    let wrap_left = 'Result<'
    let wrap_right = ', TODOError>'
  else
    let wrap_left = wrap_type.'<'
    let wrap_right = '>'
  endif

  if wrap_type == 'Result'
    let value_wrapper = 'Ok'
  elseif wrap_type == 'Option'
    let value_wrapper = 'Some'
  else
    let value_wrapper = wrap_type.'::new'
  endif

  let saved_view = winsaveview()
  let skip_syntax = rust_wrap#SkipSyntax(['String', 'Comment'])

  try
    " to the end of the line, so it works on the first line of the function
    normal! $

    " Handle return type:
    if rust_wrap#SearchSkip(')\_s\+->\_s\+\zs.\{-}\ze\s*\%(where\|{\)', skip_syntax, 'Wbc') > 0
      " there's a return type, match it, wrap it:
      call rust_wrap#Keeppatterns('s/\%#.\{-}\ze\s*\%(where\|{\)/'.wrap_left.'\0'.wrap_right.'/')
    elseif rust_wrap#SearchSkip(')\_s*\%(where\|{\)', skip_syntax, 'Wbc') > 0
      " no return type, so consider it ():
      call rust_wrap#Keeppatterns('s/)\_s*\%(where\|{\)/'.wrap_left.'()'.wrap_right.'/')
    endif

    " Find start and end of function:
    let start_line = line('.')
    call rust_wrap#SearchSkip('{$', skip_syntax, 'Wc')
    normal! %
    let end_line = line('.')
    exe start_line

    " Handle return statements:
    while search('\<return\s\+.*;', 'W', end_line) > 0
      let syntax_group = synIDattr(synID(line('.'),col('.'),1),'name')
      if syntax_group == 'rustKeyword'
        call rust_wrap#Keeppatterns('s/\%#return \zs.*\ze;/'.value_wrapper.'(\0)/')
      end
    endwhile

    " Handle end expression
    let first_line = nextnonblank(start_line + 1)
    let last_line = prevnonblank(end_line - 1)
    call s:WrapExpression(first_line, last_line, value_wrapper)
  finally
    call winrestview(saved_view)
  endtry
endfunction

" TODO (2020-05-06) Comments at the ends of expressions
" TODO (2020-05-06) Instead of lines, use [line, col] to handle partial blocks? Or just check if it's a match branch
function! s:WrapExpression(first_lineno, last_lineno, wrapper)
  call rust_wrap#PushCursor()

  try
    let first_lineno      = a:first_lineno
    let last_lineno       = a:last_lineno
    let wrapper           = a:wrapper

    if first_lineno == last_lineno
      " it's a single line, just wrap it and exit
      let body = rust_wrap#Trim(getline(first_lineno))
      let body = wrapper.'('.body.')'
      call rust_wrap#ReplaceMotion('V', body)
      return
    endif

    let expr_start_lineno = a:last_lineno
    let current_lineno    = a:last_lineno
    let prev_lineno       = prevnonblank(last_lineno - 1)

    let skip_syntax      = rust_wrap#SkipSyntax(['String', 'Comment'])
    let operator_pattern = '[,*/%+\-|.]'

    " jump to the line
    exe last_lineno
    normal! $

    let else_pattern = '^\s*\zs}\s\+else\%(\s\+if\s\+.*\)\=\s\+{$'
    let match_pattern = '\<match\s\+.*{$'

    if rust_wrap#SearchSkip('}$', skip_syntax, 'Wbc', last_lineno) > 0
      " it's a block, find its opening
      normal! %
      let first_lineno = line('.')
      let expr_first_lineno = nextnonblank(first_lineno + 1)
      let expr_last_lineno = prevnonblank(last_lineno - 1)

      if rust_wrap#SearchSkip(else_pattern, skip_syntax, 'Wbc', first_lineno) > 0
        " it's an if-else block, wrap its last expression and loop upwards
        call s:WrapExpression(expr_first_lineno, expr_last_lineno, wrapper)

        while rust_wrap#SearchSkip(else_pattern, skip_syntax, 'Wbc', first_lineno) > 0
          let last_lineno = line('.')
          normal! %
          let first_lineno = line('.')
          let expr_first_lineno = nextnonblank(first_lineno + 1)
          let expr_last_lineno = prevnonblank(last_lineno - 1)

          call s:WrapExpression(expr_first_lineno, expr_last_lineno, wrapper)
        endwhile
      elseif rust_wrap#SearchSkip(match_pattern, skip_syntax, 'Wbc', first_lineno) > 0
        " it's a match statement, find all of its => branches and wrap those up:
        while rust_wrap#SearchSkip('=>\s*\zs\S', skip_syntax, 'W', last_lineno) > 0
          if getline('.')[col('.') - 1] == '{'
            " it's a block, wrap it recursively
            call rust_wrap#PushCursor()
            let nested_first_lineno = nextnonblank(line('.') + 1)
            normal! %
            let nested_last_lineno = prevnonblank(line('.') - 1)
            call s:WrapExpression(nested_first_lineno, nested_last_lineno, wrapper)
            call rust_wrap#PopCursor()
          else
            let body = rust_wrap#Trim(rust_wrap#GetMotion('vg_'))

            " TODO (2020-05-06) trailing comments
            let trailer = matchstr(body, ',$')
            let body = substitute(body, ',$', '', '')
            let body = wrapper.'('.body.')'
            call rust_wrap#ReplaceMotion('vg_', body . trailer)
          endif

          normal! j0
        endwhile
      else
        " normal block, wrap its last expression:
        call s:WrapExpression(expr_first_lineno, expr_last_lineno, wrapper)
      endif

      return
    endif

    while rust_wrap#SearchSkip('^\s*'.operator_pattern, skip_syntax, 'Wbc', current_lineno) > 0 ||
          \ rust_wrap#SearchSkip(operator_pattern.'\s*$', skip_syntax, 'Wb', prev_lineno) > 0
      let expr_start_lineno = prev_lineno
      let current_lineno    = prev_lineno
      let prev_lineno       = prevnonblank(prev_lineno - 1)

      normal! k

      if prev_lineno < first_lineno
        " we've gone past the start of the function, bail out
        return
      endif
    endwhile

    let body = rust_wrap#Trim(join(getbufline('%', expr_start_lineno, last_lineno), "\n"))
    let body = wrapper.'('.body.')'
    call rust_wrap#ReplaceLines(expr_start_lineno, last_lineno, body)
  finally
    call rust_wrap#PopCursor()
  endtry
endfunction

function! s:WrapComplete(argument_lead, _command_line, _cursor_position)
  let types = copy(s:wrap_types)
  call filter(types, {_, t -> t =~? a:argument_lead})
  call sort(types)
  return types
endfunction
