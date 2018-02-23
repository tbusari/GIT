# Set Bash Prompt

# For interactive shells only.
if [ -z "$BASH_VERSION" -o -z "$PS1" ]; then
	return
else
	export PS1="\u@\h:\[\e[1m\]\w\[\e[0m\] \$ "
fi
