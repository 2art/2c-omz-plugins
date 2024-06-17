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

##==============================================================================
##== GPG Functions
##==============================================================================
#region GPG Functions

## * gpgverify()
## gpgverify - Simple GPG verification convenience function.
##
## The function checks all relevant files that they exist and are readable, and
## that there are no other problem. It uses the keyserver specified in the
## KEYSERVER environment variable (see .zshenv). If this is unset/unavailable,
## the following keyserver is used by default:
##
##   hkps://hkps.pool.sks-keyservers.net:443
##
## You can provide a keyserver URL and possibly port manually as the first
## argument. This will override the environment variable and the above default.
## The first parameter is checked for a match with URL regex pattern. It should
## start with either "http(s)://" or "hkp(s)://".
##
## For the GPG verification, it effectively just runs the following command:
##
##   gpg --keyserver [KEYSERVER] \
##       --keyserver-options auto-key-retrieve \
##       --verify [FILE] [SIG]
##
## Usage:
##
##   When providing a single file, if that file's extension is ".sig", then
##   the function automatically searches for a file with the same name but
##   without the extension. If the filename does NOT end in ".sig", the
##   function searches for a signature with same name and ".sig" extension.
##
##     gpgverify [FILE/SIG]                 # Provide only file or sig file; Auto-search the other
##     gpgverify [FILE] [SIG]               # Provide both, file and sig file
##     gpgverify [KEYSERVER] [FILE/SIG]     # Provide custom keyserver URL and find file/sig
##     gpgverify [KEYSERVER] [FILE] [SIG]   # Provide custom keyserver URL and both file and sig
##     KEYSERVER=[URL] gpgverify [OPTIONS]  # Alternatively use the KEYSERVER variable
##
##   FILE:
##     Path to a file to check; Must not have the extension ".sig", and must be
##     a regular readable file.
##
##   SIG:
##     Path to the relevant signature file, with ".sig" extension.
##
##   KEYSERVER:
##     Custom keyserver URL and optionally port (separated from URL by a colon)
##     to use instead of the one specified in KEYSERVER variable, or the default
##     of "hkps://hkps.pool.sks-keyservers.net:443". Below are some options:
##
##         http://keyserver.pgp.com      https://pgpkeys.eu
##         https://pgp.mit.edu           https://keys.openpgp.org
##         keyserver.ubuntu.com          hkp://pgp.mit.edu
##
gpgverify() {
	local defks=hkps://hkps.pool.sks-keyservers.net:443   # Default keyserver if not specified otherwise
	local keyserver=${KEYSERVER:-$defks}                  # Keyserver to use; Check KEYSERVER env var
	local tgtfile=""                                      # Target file name
	local tgtsig=""                                       # Target signature file for above file
	local usesudo=false                                   # If sudo is needed to read an unreadable file

	# Check if first argument is an URL to override the keyserver. First check for a prefix of http(s)
	# or hkp(s). If not present, check if it's in an URL form otherwise. Do this before checking if
	# help should be output, as if a keyserver is passed, arguments are shifted, and so if it's the
	# only parameter, help is shown.
	if [[ $1 =~ '(https?|hkps?|ftp|file)://' ]]; then
		local keyserver="$1"
		shift
	elif [[ $1 =~ '^[a-zA-Z-]+://' ]]; then
		printf '\e[31;1mError (Abort): Keyserver URL is malformed (prefix): "%s"\e[0m\n' "$1" >&2
		return 1
	fi

	# Check if the user needs help (also activated if no arguments are passed by 'help0' alias)
	if [[ $# -eq 0 || $@ =~ '(^-h| -h|--help$|--help |^-[[:alnum:]]*h| -[[:alnum:]]*h)' ]]; then
		cat <<-EOF && return 0
		$funcstack[1] - Simple GPG verification convenience function.

		The function checks all relevant files that they exist and are readable, and
		that there are no other problem. It uses the keyserver specified in the
		KEYSERVER environment variable (see .zshenv). If this is unset/unavailable,
		the following keyserver is used by default:

			hkps://hkps.pool.sks-keyservers.net:443

		You can provide a keyserver URL and possibly port manually as the first
		argument. This will override the environment variable and the above default.
		The first parameter is checked for a match with URL regex pattern. It should
		start with either "http(s)://" or "hkp(s)://".

		For the GPG verification, it effectively just runs the following command:

			gpg --keyserver [KEYSERVER] \
					--keyserver-options auto-key-retrieve \
					--verify [FILE] [SIG]

		Usage:

			When providing a single file, if that file's extension is ".sig", then
			the function automatically searches for a file with the same name but
			without the extension. If the filename does NOT end in ".sig", the
			function searches for a signature with same name and ".sig" extension.

				$funcstack[1] [FILE/SIG]                # Provide only file or sig file; Auto-search the other
				$funcstack[1] [FILE] [SIG]              # Provide both, file and sig file
				$funcstack[1] [KEYSERVER] [FILE/SIG]    # Provide custom keyserver URL and find file/sig
				$funcstack[1] [KEYSERVER] [FILE] [SIG]  # Provide custom keyserver URL and both file and sig
				KEYSERVER=[URL] $funcstack[1] [OPTIONS] # Alternatively use the KEYSERVER variable

			FILE:
				Path to a file to check; Must not have the extension ".sig", and must be
				a regular readable file.

			SIG:
				Path to the relevant signature file, with ".sig" extension.

			KEYSERVER:
				Custom keyserver URL and optionally port (separated from URL by a colon)
				to use instead of the one specified in KEYSERVER environment variable.
				Recommended to always use HKPS (HKP over TLS) - This encrypts the
				connection to the keyserver and helps prevent man-in-the-middle attacks.
				Also, TCP Port 443 is just as unlikely to be blocked by a corporate
				firewall as Port 80 (unlike Port 11371). Some alternative options:

						hkps://keyserver.pgp.com:443     hkps://pgpkeys.eu:443
						hkps://pgp.mit.edu:443           hkps://keys.openpgp.org:443
						hkps://keyserver.ubuntu.com:443  hkps://pgp.mit.edu:443
EOF
	fi

	# Check arguments and determine target file and it's signature file.
	if (( $# >= 2 )); then
		# Two arguments provided; First argument is the file, while second is for the signature file.
		tgtfile="$1"
		tgtsig="$2"
	elif [[ $1 == *.sig ]]; then
		# Only argument ends in .sig; Assuming this is the signarure file. Stripping the .sig
		# extension out for the target filename.
		tgtfile="${1%.sig}"
		tgtsig="$1"
	else
		# Only argument does not end in .sig; Assuming it is a filename and setting tgtsig to the
		# same name with .sig extension prepended to it.
		tgtfile="$1"
		tgtsig="$1.sig"
	fi

	# Begin operation; Print the file, signature and keyserver used.
	printf '\e[34;1mChecking file: \e[3;4m%s\n\e[23;24mSignature file: \e[3;4m%s\n\e[23;24mKeyserver: \e[3;4m%s\e[0m\n\n' "$tgtfile" "$tgtsig" "$keyserver"

	# Ensure that both the file and signature file exist, and are both regular readable files.
	for file in $tgtfile $sigfile; do
		if [[ ! -e $file ]]; then
			printf '\e[31;1mError (Abort): File not found: "%s"\e[0m\n' "$file" >&2
			return 1
		elif [[ ! -f $file ]]; then
			printf '\e[31;1mError (Abort): File is not a regular file: "%s"\e[0m\n' "$file" >&2
			return 1
		elif [[ ! -r $file ]]; then
			printf '\e[33;1mFile is unreadable: "%s"\n\tWould you like to read it using sudo? [Y/n]: \e[0m' "$file"
			read -k1 yn; echo
			if [[ $yn =~ '^[nN]$' ]]; then
				printf '\e[31;1mError (Abort): Cannot read file: %s\e[0m\n' "$file" >&2
				return 1
			else
				usesudo=true
			fi
		fi
	done

	# All seems to be in order; Notify and verify the signature.
	printf '\e[34;1mVerifying file..\e[0m\n'
	if $usesudo; then
		sudo gpg --keyserver-options auto-key-retrieve --verify "$tgtsig" "$tgtfile"
	else
		gpg --keyserver-options auto-key-retrieve --verify "$tgtsig" "$tgtfile"
	fi
}

## * gpgks()
## gpgks - Prints out a GPG keyserver address, from KEYSERVERS environment array. If called without
## arguments, it will print out all the options. See that keyserver list for associated numbers.
## This function will also export the resulting keyserver into the KEYSERVER environment variable.
##
## Usage:
##
##   gpgks (-h|--help)##         # Print this help information
##   gpgks (-h|--help) [NUM]     # Get specific keyserver printed out
##   gpgks [-l|--list|l(ist)]    # List keyservers and associated numbers
##   gpgks [-a|--all|a(ll)]      # Plain keyserver list appropriate for looping
##   gpgks [-q|--quiet|q(uiet)]  # Only exports the keyserver, no printing
##
## Commands:
##
##   -h, --help
##
##     Prints this help information.
##
##   l, -l, --list, list:
##
##     List all the keyservers specified in the array, numbered from 1 onward.
##     This shows the number you need to pass this function for a specific server.
##
##   a, -a, --all, all
##
##     Lists all keyservers line-by-line without any formatting or numbers. This
##     can be useful for looping, for example.
##
##   q, -q, --quiet, quiet
##
##     Only exports the requested keyserver to the KEYSERVER environment
##     variable without outputting it to the terminal.
##
gpgks() {
	local -a nums=()    # User input numbers for printing keyservers; Use array just in case the user
											# wants to print out multiple keyservers, for some reason.
	local list=false    # Whether to list all keyservers with numbers
	local all=false     # Whether to list keyservers without numbering or format
	local quiet=false   # Whether to quietly only export KEYSERVER

	if [[ $@ =~ '(^-h| -h|--help$|--help |^-[[:alnum:]]*h| -[[:alnum:]]*h)' ]]; then
		cat <<-EOF && return 0
			$funcstack[1] - Prints out a GPG keyserver address, from KEYSERVERS environment array.
			If called without arguments, it will print out all the options. See that
			keyserver list for associated numbers. This function will also export the
			resulting keyserver into the KEYSERVER environment variable.

			Usage:

				$funcstack[1] (-h|--help)           # Print this help information
				$funcstack[1] (-h|--help) [NUM]     # Get specific keyserver printed out
				$funcstack[1] [-l|--list|l(ist)]    # List keyservers and associated numbers
				$funcstack[1] [-a|--all|a(ll)]      # Plain keyserver list appropriate for looping
				$funcstack[1] [-q|--quiet|q(uiet)]  # Only exports the keyserver, no printing

			Commands:

				-h, --help

					Prints this help information.

				l, -l, --list, list:

					List all the keyservers specified in the array, numbered from 1 onward.
					This shows the number you need to pass this function for a specific server.

				a, -a, --all, all

					Lists all keyservers line-by-line without any formatting or numbers. This
					can be useful for looping, for example.

				q, -q, --quiet, quiet

					Only exports the requested keyserver to the KEYSERVER environment
					variable without outputting it to the terminal.
EOF
	fi

	# Output list by default if no other parameters.
	(( $# <= 0 )) && list=true

	# Process command line arguments.
	for arg in $@; do
		# Check for -l (list) parameter
		if [[ $arg =~ '^(-l|(--)?l(ist)?)$' ]]; then
			list=true
		# Check for -a (all) parameter
		elif [[ $arg =~ '^(-a|(--)?a(ll)?)$' ]]; then
			all=true
		# Check for -q (quiet) parameter
		elif [[ $arg =~ '^(-q|(--)?q(uiet)?)$' ]]; then
			quiet=true
		# Since the parameter is not any of the three available commands, it must then be a number for
		# the keyserver to print. Ensure the parameter is a number.
		elif ! [[ $arg =~ '^-?[0-9]+$' ]]; then
			printf '\e[31;1mError: Invalid parameter "%s" (not a number).\e[0m\n' "$arg" >&2
			return 1
		# Parameter is a number; Now check that it's within bounds.
		elif (( $arg < 0 || $arg > $#KEYSERVERS )); then
			printf '\e[31;1mError: Number %d is out of range. Choose a value between 0 and %d.\e[0m\n' $arg $#KEYSERVERS >&2
			return 1
		# Paratered is a valid in-bounds number. Add it to the nums array.
		else
			nums+=$arg
		fi
	done

	# List keyservers with numbers if requested.
	if $list; then
		for i in $(seq 1 $#KEYSERVERS); do
			printf '\e[36;1m%d: \e[4m%s\e[0m\n' $i "${KEYSERVERS[$i]}"
		done
	# List keyservers plain with no formatting or numbers if requested.
	elif $all; then
		for server in "${KEYSERVERS[@]}"; do
			printf '%s\n' "$server"
		done
	# Default; Print out all keyservers based on the numbers user input.
	else
		export KEYSERVER="$KEYSERVERS[$nums[-1]]" # Use last input number as the exported index
		$quiet || for ksnum in ${nums[@]}; do printf '%s\n' "$KEYSERVERS[$ksnum]"; done
	fi
}

#endregion
