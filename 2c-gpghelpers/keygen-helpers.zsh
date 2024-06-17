#!/usr/bin/env zsh

##==============================================================================
##== Key Generation
##==============================================================================
#region Key Generation


_interactive_keygen() {
	while true; do
		_print_query_question "Full name"
		_query_input_string -c name | read name
		_validate_input "$name" name && break
	done

	while true; do
		_print_query_question "Email"
		_query_input_string -c email | read email
		_validate_input "$email" email && break
	done

	_print_query_question "Password"
	_query_input_string -p | read pw && printf '\e[0m\n'


	printf '\e[32;1mFull Name: \e[0;32;2m%s\e[0m\n' $name
	printf '\e[32;1mEmail: \e[0;32;2m%s\e[0m\n' $email
	printf '\e[32;1mPassword: \e[0;32;2m%s\e[0m\n' $pw
}

#endregion

##==============================================================================
##== Helper Functions
##==============================================================================
#region Helper Functions

_print_query_question() {
	if (( $# == 0 )); then
		printf '\e[0;31;1mError (%s): No query message provided.\e[0m\n' "$funcstack[1]" >&2
	else
		printf '\e[0;32;1m%s: \e[0;32;2m' "$1"
	fi
}

_query_input_string() {
	# If -h|--help specified or no args provided, output help information.
	if [[ $# -eq 0 || $@ =~ '(^-h| -h|--help$|--help |^-[[:alnum:]]*h| -[[:alnum:]]*h)' ]]; then
		cat <<-EOF && return 0
			$funcstack[1] - Query an input string from the user.

			Usage: $funcstack[1] [-p|--password]
			(Note that the parameters and args can be passed in any order.)

				-p|--password
					Query the user for a password; User input won't be visibly printed.
		EOF
	# Check for -p|--password
	elif [[ $@ =~ '(^-p| -p|--password$|--password |^-[[:alnum:]]*p| -[[:alnum:]]*p)' ]]; then
		# Read password
		read -s input
	else
		# Read normal input
		read input
	fi

	# Done; Print the result
	printf '%s\n' "$input"
}

_validate_input() {
	# If -h|--help specified or no args provided, output help information.
	if [[ $# -lt 2 || $@ =~ '(^-h| -h|--help$|--help |^-[[:alnum:]]*h| -[[:alnum:]]*h)' ]]; then
		cat <<-EOF && return 0
			$funcstack[1] - Query an input string from the user.

			Usage: $funcstack[1] [INPUT] [VALIDATION_TYPE]

				INPUT
					Input string to validate.

				VALIDATION_TYPE
					Type to validate; Currently available: "name", "email".
		EOF
	fi

	local input="$1" # Get input from first argument.
	local valtype="$2" # Get validation type from second argument.

	# Ensure validation type value is valid.
	if [[ $valtype == 'email' ]]; then
		# Check that input is a valid email.
		if echo $input | pcre2grep '^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$' | read input_checked; then
			return 0
		else
			printf "\e[31;1mError: Invalid email "%s". (Matched against: \$'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\$').\e[0m\n" "$input" >&2
			return 1
		fi
	elif [[ $valtype == 'name' ]]; then
		# Check that input is a valid name.
		if echo $input | pcre2grep $'^[A-Z][a-zA-Z \'.-]*((?![0-9])[^-])$' | read input_checked; then
			return 0
		else
			printf "\e[31;1mError: Invalid name "%s" (Matched against: \$'^[A-Z][a-zA-Z \'.-]*((?![0-9])[^-])$').\e[0m\n" "$input" >&2
			return 1
		fi
	else
		printf '\e[31;1mError in _validate_input(): validation type value "%s" is invalid; Must be "name" or "email".\e[0m\n' "$valtype" >&2
		return 1
	fi
}

#endregion
