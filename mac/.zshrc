# Extra commands I like in my ~/.zshrc
# Add these to the rc file, don't replace the whole config
plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

zmodload zsh/mapfile
eval "$(zoxide init zsh --cmd cd)"
eval "$(starship init zsh)"

alias tnotes="cd ~/projects/second-brain/Vault/Vault/ && nvim"
alias cwp="~/.scripts/wallpaper-scripts/set-random-wallpaper.sh"
alias bwp="~/.scripts/wallpaper-scripts/blacklist-wallpaper.sh"

fastfetch
