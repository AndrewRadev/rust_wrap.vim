if exists('g:loaded_rust_wrap') || &cp
  finish
endif

let g:loaded_rust_wrap = '0.0.1' " version number
let s:keepcpo = &cpo
set cpo&vim


let &cpo = s:keepcpo
unlet s:keepcpo
