" Vim syntax file
" Language: SLAP

" Usage Instructions
" Put this file to ~/.vim/syntax directory:
"	cp editor/slap.vim ~/.vim/syntax/
" And add the following line to your ~/.vimrc: 
" autocmd BufRead,BufNewFile *.slap set filetype=slap

if exists("b:current_syntax")
    finish
endif

" Language keywords
syntax keyword SLAPKeywords def and let const or if elif else for super while self return continue break class static import

" Type keywords
syntax keyword SLAPType int float string null

" Boolean
syntax keyword SLAPBool true false

" Numbers
syntax match SLAPNum "\d\+"

" Stringß
syntax region SLAPString start="\"" end="\""

" Comments
syntax match SLAPComment "#.*$" contains=SLAPMLComment
syntax region SLAPMLComment start="#{" end="}#"

" Ops
syntax match valeOp "[+\-\*/@&$=<>!]"

" Set highlights
highlight default link SLAPKeywords    Repeat
highlight default link SLAPNum         Number
highlight default link SLAPString      String
highlight default link SLAPType        Type
highlight default link SLAPBool        Boolean
highlight default link SLAPComment     Comment
highlight default link SLAPMLComment   Comment

let b:current_syntax = "slap"
