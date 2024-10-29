set fish_greeting ""



## All the alias here
alias ls "lsd"
alias cat "bat"
alias tree "exa -T"
alias grep "grep --color=auto"
alias pypwd "python /home/hectorio23/Desktop/pypwd/pypwd.py"
alias dotnet "~/.dotnet/dotnet"


# Fish custom prompt 
starship init fish | source

export PATH="$PATH:/home/hectorio23/.dotnet/tools"
