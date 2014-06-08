" Author: Marcin Szamotulski, © 2012
" License: Vim-License, see :help license

fun! ViewPort(cmd, s_line, e_line, ...) " {{{1
    if !has("autocmd")
	echohl WarningMsg
	echom "[ViewPort]: requires +autocmd feature"
	echohl Normal
	return
    endif
    if a:0
	let s_mark = ( stridx(a:1, "'") == 0 ? a:1 : "'".a:1 )
    else
	let s_mark = "'t"
    endif
    if a:0 >= 2
	let e_mark = ( stridx(a:2, "'") == 0 ? a:2 : "'".a:2 )
    else
	let e_mark = "'y"
    endif
    if s_mark == e_mark
	echohl WarningMsg
	echomsg "[ViewPort]: starting mark and ending mark have to be distinct"
	echohl Normal
	return
    endif
    let lines = getbufline("%", a:s_line, a:e_line)
    call setpos(s_mark, [0, a:s_line, 0, 0])
    call setpos(e_mark, [0, a:e_line, 0, 0])
    let bufnr = bufnr("%")
    let ft = &filetype
    if !empty(ft)
	exe a:cmd.' +setl\ ft='.ft.'\ buftype=acwrite viewport://'.fnameescape(expand('%:p').' '.s_mark.'-'.e_mark)
    else
	exe a:cmd.' +setl\ buftype=acwrite viewport://'.fnameescape(expand('%:p').' '.s_mark.'-'.e_mark)
    endif
    setl ma
    let &l:statusline = ''
    %d_
    let b:viewport_address = [bufnr, s_mark, e_mark]
    call append(1,lines)
    0d_
    " Reset undo:
    let ul = &ul
    set ul=-1
    exe "normal a \<bs>\<esc>"
    let &ul=ul
    unlet ul
    set nomodified
    com! -buffer Update :call <sid>Read()

    let b:viewport_lines = lines
endf
com! -range -nargs=* Vpedit :call ViewPort("edit", <line1>, <line2>, <f-args>)
com! -range -nargs=* Vpvsplit :call ViewPort("vsplit", <line1>, <line2>, <f-args>)
com! -range -nargs=* Vpsplit :call ViewPort("split", <line1>, <line2>, <f-args>)
fun! <sid>Read() " {{{1
    let s_view = winsaveview()
    let c_pos = getpos(".")
    let c_bufnr = bufnr("%")
    let hid = &hid
    set hid
    let address = b:viewport_address
    exe "keepalt b ".b:viewport_address[0]
    let s_pos = getpos(address[1])
    let e_pos = getpos(address[2])
    if s_pos == [0, 0, 0, 0]
	exe "keepalt b ".c_bufnr
	let &hid = hid
	" XXX: I could make this work with :echomsg.
	echoerr "[ViewPort]: the begin mark \"".address[1]."\" was deleted, aborting."
	return
    elseif e_pos == [0, 0, 0, 0]
	exe "keepalt b ".c_bufnr
	let &hid = hid
	echoerr "[ViewPort]: the end mark \"".address[2]."\" was deleted, aborting."
	return
    elseif s_pos[1] > e_pos[1]
	let address[1:2] = [ address[2], address[1] ] 
	let [ s_pos, e_pos ] = [ e_pos, s_pos ]
    endif
    let lines = getbufline(address[0], s_pos[1], e_pos[1])
    exe "keepalt b ".c_bufnr
    let &hid = hid
    %d_
    call append(1, lines)
    0d_
    let c_line = min([c_pos[1], len(lines)])
    call cursor(c_line, 0)
    call winrestview(s_view)
    let b:viewport_lines = lines
    setl nomod
endf
fun! <sid>Write() " {{{1

    silent preserve

    let lines = getbufline("%", 0, "$")
    let address = b:viewport_address
    let vp_lines = b:viewport_lines
    let winnr = bufwinnr(b:viewport_address[0])
    let winview = winsaveview()
    if winnr != -1
	let c_winnr = winnr()
	exe winnr."wincmd w"
    else
	let c_bufnr = bufnr("%")
	let hid = &hid
	set hid
	try
	    exe "buffer ".address[0]
	catch /E86:/
	    echohl ErrorMsg
	    echomsg "[ViewPort]: buffer ".address[0]." does not exists"
	    echohl Normal
	    return
	endtry
    endif
    let s_pos = getpos(address[1])
    let e_pos = getpos(address[2])
    if s_pos == [0, 0, 0, 0]
	echohl WarningMsg
	echomsg "[ViewPort]: the begin mark \"".address[1]."\" was deleted, aborting."
	echohl Normal
	return
    elseif e_pos == [0, 0, 0, 0]
	echohl WarningMsg
	echomsg "[ViewPort]: the end mark \"".address[2]."\" was deleted, aborting."
	echohl Normal
	return
    endif
    let s_line = s_pos[1]
    let e_line = e_pos[1]
    let c_lines = getline(s_line, e_line)
    let test = v:cmdbang || c_lines == vp_lines
    let ma = &l:ma
    if (test) && (ma)
	exe "silent! ".s_line.",".e_line."delete _"
	call append(s_line-1, lines)
	call setpos(address[1],[0, s_line, 0, 0])
	call setpos(address[2],[0, s_line+len(lines)-1, 0, 0])
    elseif !(ma)
	echohl ErrorMsg
	echom "[ViewPort]: Cannot make changes, 'modifiable' is off in the target"
	echohl None
    endif
    if exists("c_winnr")
	exe c_winnr."wincmd w"
	unlet c_winnr
    elseif exists("c_bufnr")
	exe "buffer ".c_bufnr
	let &hid = hid
	unlet c_bufnr
    endif
    call winrestview(winview)
    if !(ma)|return|endif
    if !(test)
	echohl ErrorMsg
	echom "[ViewPort]: target buffer modified, use w! to overwrite"
	echohl Normal
    else
	setl nomod
	let b:viewport_lines = lines
    endif
endf

augroup Part_WriteCmd
    au!
    au BufWriteCmd viewport://* :call <sid>Write()
augroup END
