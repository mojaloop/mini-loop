#add this to end of .bashrc to set prompt to include git branch
RED="\e[31m"
GREEN="\e[32m"
ENDCOLOR="\e[0m"

parse_git_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}
export PS1="$GREEN\u@\h \[\033[32m\]\w$RED\$(parse_git_branch)$ENDCOLOR $ "

