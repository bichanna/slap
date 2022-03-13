#!/bin/bash

# colors for echo
RED='\033[0;31m'
GREEN='\033[0;32m'
LBLUE='\033[1;34m'
NC='\033[0m'

# check if Nim is installed
if ! command -v nimble &> /dev/null
then
  # ask user if he or she would like to install Nim now
  echo "Nim is not installed."
  read -p "Would you like to install Nim? [y/N]: " answer
  if [[ $answer == *"yes"* ]]
  then
    curl https://nim-lang.org/choosenim/init.sh -sSf | sh
    
  else
    echo "Nim installation canceled"
	exit 0
  fi
fi

# actually building the source code
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
  # there was a problem compiling the source code of SLAP
  echo -e "${RED}Failed${NC}"
  echo -e "Please run this command: ${LBLUE}nimble build --multimethods:on --verbose --debug${NC}"
  echo -e "And open an issue on Github: ${LBLUE}https://github.com/bichanna/slap/issues${NC}"
  exit 1
fi 