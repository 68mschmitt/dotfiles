## Create the alias on the remote machine
 - alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

## Clone the repo onto the machine
 - git clone --bare git@github.com:68mschmitt/dotfiles.git $HOME/.dotfiles



## To add files to track into the repo
 - dotfiles add ./{files/directories}


## Use the dotfiles command in place of git
