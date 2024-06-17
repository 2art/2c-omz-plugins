#!/usr/bin/env zsh

##==============================================================================
##== Output Formatting & Convenience
##==============================================================================
#region Output Formatting & Convenience

## * _out_error
## Prints an error including plugin name etc. to avoid confusion
##
## Usage: _out_error [PRINTF-FORMAT] ([ADDITIONAL-ARGS...])
##
##   PRINTF-FORMAT:
##     Format for printf call; The message will be prefixed with red-colored
##     text "Plugin "<plugin name>" error: " followed by a string generated
##     by passing PRINTF-FORMAT to 'printf' along with the rest of the passed
##     arguments. Just make sure if you include %s etc., that you provide
##     the same amount of corresponding additional arguments.
##
##   ADDITIONAL-ARGS
##     Arguments for the printf format specified above. This is optional; Only
##     the format can be passed for a simple message.
##
_out_error() {
	# If -h|--help specified or no args provided, output help information.
	if [[ $# -eq 0 || $@ =~ '(^-h| -h|--help$|--help |^-[[:alnum:]]*h| -[[:alnum:]]*h)' ]]; then
		cat <<-EOF && return 0
			$funcstack[1] - Prints an error including plugin name etc. to avoid confusion

			Usage: $funcstack[1] [PRINTF-FORMAT] ([ADDITIONAL-ARGS...])

				PRINTF-FORMAT:
					Format for printf call; The message will be prefixed with red-colored
					text "Plugin "<plugin name>" error: " followed by a string generated
					by passing PRINTF-FORMAT to 'printf' along with the rest of the passed
					arguments. Just make sure if you include %s etc., that you provide
					the same amount of corresponding additional arguments.

				ADDITIONAL-ARGS
					Arguments for the printf format specified above. This is optional; Only
					the format can be passed for a simple message.

EOF
	fi

	# Alls good; Output the error message.
	printf '\e[31;1m(%s) Plugin error: %s\e[0m\n' "${_PLUGIN_NAME}" "$(printf "${1}" ${@:2})" >&2
}

#endregion
