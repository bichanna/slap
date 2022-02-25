#!/bin/bash

# colors for echo
RED='\033[0;31m'
GREEN='\033[0;32m'
LBLUE='\033[1;34m'
NC='\033[0m'

# check if Nim is installed
if ! command -v nimble &> /dev/null
then
  echo "Nim is not installed."
  echo -e "Please install Nim: ${LBLUE}https://nim-lang.org/install.html${NC}"
  exit 1
fi

# actually building the language
echo "Building SLAP..."
nimble build --multimethods:on -d:release --silent

# check if building the langauge finished with status 0 (success)
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
	echo -e "And open an issue on Github: ${LBLUE}https://github.com/bichanna/slap/issues${NC}"
	exit 1
fi 