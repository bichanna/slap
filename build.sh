#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
LBLUE='\033[1;34m'
NC='\033[0m'

echo "Building SLAP..."
nimble build --multimethods:on -d:release --silent

# if the compilation finished with status 0
if [ $? -eq 0 ]; then
	cp ./main /usr/local/bin/slap
	cp ./editor/slap.vim ~/.vim/syntax
	echo "autocmd BufRead,BufNewFile *.slap set filetype=slap" >> ~/.vimrc
	echo -e "${GREEN}Completed${NC}"
	echo -e "${GREEN}Usage: 'slap [filename.slap]'${NC}"
	exit 0
else
	# there was a problem compiling the source code
	echo -e "${RED}Failed${NC}"
	echo -e "Please run this command: ${LBLUE}nimble build --multimethods:on --verbose --debug${NC}"
	echo "And open an issue on Github: https://github.com/bichanna/slap/issues"
	exit 1
fi 