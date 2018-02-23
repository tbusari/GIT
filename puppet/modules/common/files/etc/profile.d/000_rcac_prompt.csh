# Set (t)csh Prompt

# For interactive shells only.
if ( $?prompt ) then
	set promptchars = '$#'
        set prompt = '%n@%m:%B%~%b %# '
endif
