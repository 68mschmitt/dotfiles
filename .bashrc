#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

export DOTNET_ROOT=/opt/dotnet
alias dotfiles=/usr/bin/git --git-dir=$HOME/.dotfiles --work-tree=$HOME
