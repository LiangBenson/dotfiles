#!/bin/zsh

set -euo pipefail

echo "Building fzf"
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
(cd ~/.fzf &&
	./install)
