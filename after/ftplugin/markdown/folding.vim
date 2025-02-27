" Fold expressions {{{1
function! StackedMarkdownFolds()
  let thisline = getline(v:lnum)
  let prevline = getline(v:lnum - 1)
  let nextline = getline(v:lnum + 1)
  
  if HeadingDepth(v:lnum) > 0
    return ">1"
  else
    return "="
  endif
endfunction

function! NestedMarkdownFolds()
  let thisline = getline(v:lnum)
  let prevline = getline(v:lnum - 1)
  let nextline = getline(v:lnum + 1)
  if thisline =~ '^```.*$' && prevline =~ '^\s*$'  " start of a fenced block
    return "a1"
  elseif thisline =~ '^```$' && nextline =~ '^\s*$'  " end of a fenced block
    return "s1"
  endif

  let depth = HeadingDepth(v:lnum)
  if depth > 0
    return ">".depth
  else
    return "="
  endif
endfunction

" Helpers {{{1
function! s:SID()
  return matchstr(expand('<sfile>'), '<SNR>\d\+_')
endfunction

function! HeadingDepth(lnum)
  let level=0
  let thisline = getline(a:lnum)
  if thisline =~ '^#\+\s\+'
    let hashCount = len(matchstr(thisline, '^#\{1,6}'))
    if hashCount > 0
      let level = hashCount
    endif
  else
    if thisline != ''
      let nextline = getline(a:lnum + 1)
      if nextline =~ '^=\+\s*$'
        let level = 1
      elseif nextline =~ '^-\+\s*$'
        let level = 2
      endif
    endif
  endif
  if level > 0 && LineIsFenced(a:lnum)
    " Ignore # or === if they appear within fenced code blocks
    let level = 0
  endif
  return level
endfunction

function! LineIsFenced(lnum)
  if exists("b:current_syntax") && b:current_syntax ==# 'markdown'
    " It's cheap to check if the current line has 'markdownCode' syntax group
    return HasSyntaxGroup(a:lnum, '\vmarkdown(Code|Highlight)')
  else
    " Using searchpairpos() is expensive, so only do it if syntax highlighting
    " is not enabled
    return s:HasSurroundingFencemarks(a:lnum)
  endif
endfunction

function! HasSyntaxGroup(lnum, targetGroup)
  let syntaxGroup = map(synstack(a:lnum, 1), 'synIDattr(v:val, "name")')
  for value in syntaxGroup
    if value =~ a:targetGroup
        return 1
    endif
  endfor
endfunction

function! s:HasSurroundingFencemarks(lnum)
  let cursorPosition = [line("."), col(".")]
  call cursor(a:lnum, 1)
  let startFence = '\%^```\|^\n\zs```'
  let endFence = '```\n^$'
  let fenceEndPosition = searchpairpos(startFence,'',endFence,'W')
  call cursor(cursorPosition)
  return fenceEndPosition != [0,0]
endfunction

function! s:FoldText()
  let level = HeadingDepth(v:foldstart)
  let indent = repeat('#', level)
  let title = substitute(getline(v:foldstart), '^#\+\s\+', '', '')
  let foldsize = (v:foldend - v:foldstart)
  let linecount = '['.foldsize.' line'.(foldsize>1?'s':'').']'

  if level < 6
    let spaces_1 = repeat(' ', 6 - level)
  else
    let spaces_1 = ' '
  endif

  if exists('*strdisplaywidth')
      let title_width = strdisplaywidth(title)
  else
      let title_width = len(title)
  endif

  if title_width < 40
    let spaces_2 = repeat(' ', 40 - title_width)
  else
    let spaces_2 = ' '
  endif

  return indent.spaces_1.title.spaces_2.linecount
endfunction

" API {{{1
function! ToggleMarkdownFoldexpr()
  if &l:foldexpr ==# 'StackedMarkdownFolds()'
    setlocal foldexpr=NestedMarkdownFolds()
  else
    setlocal foldexpr=StackedMarkdownFolds()
  endif
endfunction
command! -buffer FoldToggle call ToggleMarkdownFoldexpr()

" Setup {{{1
if !exists('g:markdown_fold_style')
  let g:markdown_fold_style = 'stacked'
endif

if !exists('g:markdown_fold_override_foldtext')
  let g:markdown_fold_override_foldtext = 1
endif

function! FoldTextWorkaround()
    let level = HeadingDepth(v:foldstart)
    let indent = repeat('#', level)
    let title = substitute(getline(v:foldstart), '^#\+\s*', '', '')
    let foldsize = (v:foldend - v:foldstart)
    let linecount = '['.foldsize.' line'.(foldsize>1?'s':'').']'
    return indent.' '.title.' '.linecount
endfunction

setlocal foldmethod=expr

if g:markdown_fold_override_foldtext
  " let &l:foldtext = s:SID() . 'FoldText()'
  setlocal foldtext=FoldTextWorkaround() 
endif

let &l:foldexpr =
  \ g:markdown_fold_style ==# 'nested'
  \ ? 'NestedMarkdownFolds()'
  \ : 'StackedMarkdownFolds()'

" Teardown {{{1
if !exists("b:undo_ftplugin") | let b:undo_ftplugin = '' | endif
let b:undo_ftplugin .= '
  \ | setlocal foldmethod< foldtext< foldexpr<
  \ | delcommand FoldToggle
  \ '
" vim:set fdm=marker:
