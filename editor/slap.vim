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
syntax keyword SLAPKeywords define and let const or if elif else for super while self return continue break class static import

" Type keywords
syntax keyword SLAPType int float string null

" Boolean
syntax keyword SLAPBool true false

" Numbers
syntax match SLAPNum "\d\+"

" Set highlights
highlight default link SLAPKeywords Repeat
highlight default link SLAPNum Number
highlight default link SLAPType Type
highlight default link SLAPBool Boolean

let b:current_syntax = "slap"
