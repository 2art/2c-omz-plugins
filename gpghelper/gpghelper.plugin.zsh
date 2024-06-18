#!/usr/bin/env zsh

##======== Configuration & Keyserver Variables =================================
#region Configuration & Keyserver Variables

# Name of the plugin.
_GPGHELPER_PLUGIN_NAME="gpghelper"

# Array for possible GPG keyservers that can be accessed later in any scenario
GPGHELPER_KEYSERVERS=(
	hkps://hkps.pool.sks-keyservers.net:443
	hkps://keyserver.pgp.com:443
	hkps://pgpkeys.eu:443
	hkps://pgp.mit.edu:443
	hkps://keys.openpgp.org:443
	hkps://keyserver.ubuntu.com:443
)

# Default keyserver in case it's not specified somehow.
_GPGHELPER_DEFAULT_KEYSERVER="${GPGHELPER_KEYSERVERS[1]}"

# Main keyserver to use in GPG aliases and functions.
export GPGHELPER_KEYSERVER="${GPGHELPER_KEYSERVER:-$_GPGHELPER_DEFAULT_KEYSERVER}"

# More commonly named export for possible other uses
export KEYSERVER="${GPGHELPER_KEYSERVER}"

#endregion

##======== Useful Aliases ======================================================
#region Useful Aliases

## @ gpg
## Use default GPG keyserver every time it is called.
alias gpg="gpg --keyserver $KEYSERVER"

## @ gpg2
## Override 'gpg2' and forward it to 'gpg'.
alias gpg2=gpg

## @ gpgkeys, gpgkeysl, gpgkeyssc, gpgkeysscl
## Aliases for listing public keys and secret keys in short and long formats.
alias gpgkeys='gpg --list-public-keys --keyid-format short'
alias gpgkeysl='gpg --list-public-keys --keyid-format long'
alias gpgkeyssc='gpg --list-secret-keys --keyid-format short'
alias gpgkeysscl='gpg --list-secret-keys --keyid-format long'

## @ gpgverify, gpgkeyserver, gpgks
## Quick aliases for the custom functions provided by this plugin.
alias gpgverify='gpghelper-verify'
alias gpgkeyserver='gpghelper-keyserver'
alias gpgks='gpghelper-keyserver'

#endregion

##======== Public Functions ====================================================
#region Public Functions

## * gpghelper-keyserver()
## Prints out a GPG keyserver address, from GPGHELPER_KEYSERVERS environment
## array. If called without arguments, it will print out all the keyservers
## in a numbered list. These numbers are the ones to be used with this function
## to select a specific keyserver for the session. The new keyserver will also
## be exported to the GPGHELPER_KEYSERVER and KEYSERVER environment variables.
##
## Usage:
##
##   gpghelper-keyserver (-h|--help)  # Print this help information
##   gpghelper-keyserver              # List keyservers and associated numbers
##   gpghelper-keyserver [NUM]        # Select new keyserver for this session
##   gpghelper-keyserver (-a|--all)   # Plain keyserver list appropriate for looping
##
##   Parameters:
##     -h, --help  Prints this help information.
##     -a, --all   Lists all keyservers line-by-line without any formatting or
##                 numbers. This can be useful for looping, for example.
##     NUM         Numerical value representing a keyserver from numbered list
##                 available by calling the function with no arguments. If a
##                 number is provided, that keyserver is selected as the new
##                 default keyserver for this terminal session.
gpghelper-keyserver() {
  # Check if -h|--help is passed to print help information and quit.
	if [[ $@ =~ '(^-h| -h|--help$|--help |^-[[:alnum:]]*h| -[[:alnum:]]*h)' ]]; then
		cat <<-EOF && return 0
			$funcstack[1]

      Prints out a GPG keyserver address, from GPGHELPER_KEYSERVERS environment
      array. If called without arguments, it will print out all the keyservers
      in a numbered list. These numbers are the ones to be used with this function
      to select a specific keyserver for the session. The new keyserver will also
      be exported to the GPGHELPER_KEYSERVER and KEYSERVER environment variables.

			Usage:

				$funcstack[1] (-h|--help)  # Print this help information
				$funcstack[1]              # List keyservers and associated numbers
				$funcstack[1] [NUM..]      # Select new keyserver for this session
				$funcstack[1] (-a|--all)   # Plain keyserver list appropriate for looping

			  Parameters:
			  	-h, --help  Prints this help information.
			  	-a, --all   Lists all keyservers line-by-line without any formatting or
                      numbers. This can be useful for looping, for example.
          NUM         Numerical value representing a keyserver from numbered list
                      available by calling the function with no arguments. If a
                      number is provided, that keyserver is selected as the new
                      default keyserver for this terminal session.

		EOF
  # Check if no parameters, to print numbered keyserver list.
	elif (( $# == 0 )); then
		for i in $(seq 1 $#GPGHELPER_KEYSERVERS); do
      if [[ ${GPGHELPER_KEYSERVERS[$i]} == ${GPGHELPER_KEYSERVER} ]]; then
        printf '\e[32;1m%d: \e[2;4m%s\e[24m (Current)\e[0m\n' $i "${GPGHELPER_KEYSERVERS[$i]}"
      else
        printf '\e[32;1m%d: \e[2;4m%s\e[0m\n' $i "${GPGHELPER_KEYSERVERS[$i]}"
      fi
		done
    return 0
  # Check if -a|--all is passed, to print all keyservers without formatting, for looping.
	elif [[ $@ =~ '(^-a| -a|--all$|--all |^-[[:alnum:]]*a| -[[:alnum:]]*a)' ]]; then
    for server in "${GPGHELPER_KEYSERVERS[@]}"; do
      printf '%s\n' "$server"
    done
    return 0
  # Get the next command line argument, and expect it to be a number in range of
  # 1 to length of the keyservers array. If not, give errors.
  elif [[ ! $1 =~ '^-?[0-9]+$' ]]; then
    _gpghelper_print_error "Invalid parameter '%s'." "$arg"
    return 1
  elif (( $1 < 1 || $1 > $#GPGHELPER_KEYSERVERS )); then
    _gpghelper_print_error "Number %d is out of range. Choose a value between 1 and %d." $arg ${#GPGHELPER_KEYSERVERS}
    return 1
  else
		export GPGHELPER_KEYSERVER="${GPGHELPER_KEYSERVERS[$1]}"
		export KEYSERVER="${GPGHELPER_KEYSERVERS[$1]}"
		printf '\e[32;1mNew keyserver for session: \e[2;4m%s\e[0m\n' "${GPGHELPER_KEYSERVER}"
  fi
}

## * gpghelper-verify()
## Simple GPG verification convenience function.
##
## The function checks all relevant files that they exist and are readable, and
## that there are no other problem. It uses the keyserver specified in the
## KEYSERVER environment variable (see .zshenv). If this is unset/unavailable,
## the following keyserver is used by default: ${_GPGHELPER_DEFAULT_KEYSERVER}
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
##     gpghelper-verify [FILE/SIG]                 # Provide only file or sig file; Auto-search the other
##     gpghelper-verify [FILE] [SIG]               # Provide both, file and sig file
##     gpghelper-verify [KEYSERVER] [FILE/SIG]     # Provide custom keyserver URL and find file/sig
##     gpghelper-verify [KEYSERVER] [FILE] [SIG]   # Provide custom keyserver URL and both file and sig
##     KEYSERVER=[URL] gpghelper-verify [OPTIONS]  # Alternatively use the KEYSERVER variable
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
##     to use instead of the one specified in KEYSERVER environment variable.
##     Recommended to always use HKPS (HKP over TLS) - This encrypts the
##     connection to the keyserver and helps prevent man-in-the-middle attacks.
##     Also, TCP Port 443 is just as unlikely to be blocked by a corporate
##     firewall as Port 80 (unlike Port 11371). For alternative options, see
##     the \${GPGHELPER_KEYSERVERS} array.
gpghelper-verify() {
	# Keyserver to use; Check GPGHELPER_KEYSERVER and KEYSERVER env vars
	local keyserver="${GPGHELPER_KEYSERVER:-$_GPGHELPER_DEFAULT_KEYSERVER}"

	local tgtfile=    # Target file name
	local tgtsig=     # Target signature file for above file
	local sudo=false  # If sudo is needed to read an unreadable file

	# Check if first argument is an URL to override the keyserver. First check for a prefix of http(s)
	# or hkp(s). If not present, check if it's in an URL form otherwise. Do this before checking if
	# help should be output, as if a keyserver is passed, arguments are shifted, and so if it's the
	# only parameter, help is shown.
	if [[ $1 =~ '(https?|hkps?|ftp|file)://' ]]; then
		local keyserver="$1"
		shift
	elif [[ $1 =~ '^[a-zA-Z-]+://' ]]; then
    _gpghelper_print_error "Keyserver URL is malformed (prefix): %s" "$1"
		return 1
	fi

	# Check if the user needs help (also activated if no arguments are passed by 'help0' alias)
	if [[ $# -eq 0 || $@ =~ '(^-h| -h|--help$|--help |^-[[:alnum:]]*h| -[[:alnum:]]*h)' ]]; then
		cat <<-EOF && return 0
		$funcstack[1] - Simple GPG verification convenience function.

		The function checks all relevant files that they exist and are readable, and
		that there are no other problem. It uses the keyserver specified in the
		KEYSERVER environment variable (see .zshenv). If this is unset/unavailable,
		the following keyserver is used by default: ${_GPGHELPER_DEFAULT_KEYSERVER}

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
				firewall as Port 80 (unlike Port 11371). For alternative options, see
				the \${GPGHELPER_KEYSERVERS} array.
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
      _gpghelper_print_error "File not found: %s" "$file"
			return 1
		elif [[ ! -f $file ]]; then
      _gpghelper_print_error "File is not a regular file: %s" "$file"
			return 1
		elif [[ ! -r $file ]]; then
			printf '\e[33;1mFile is unreadable: "%s"\n\tWould you like to read it using sudo? [Y/n]: \e[0m' "$file"
			read -k1 yn; echo
			if [[ $yn =~ '^[nN]$' ]]; then
        _gpghelper_print_error "Cannot read file: %s" "$file"
				return 1
			else
				sudo=true
			fi
		fi
	done

	# All seems to be in order; Notify and verify the signature.
	printf '\e[34;1mVerifying file..\e[0m\n'
	if $sudo; then
		sudo gpg --keyserver-options auto-key-retrieve --verify "$tgtsig" "$tgtfile"
	else
		gpg --keyserver-options auto-key-retrieve --verify "$tgtsig" "$tgtfile"
	fi
}

#endregion

##======== Private Helper Functions ============================================
#region Private Helper Functions

## * _gpghelper_print_error()
## Prints an error including plugin name etc. to avoid confusion
##
## Usage: _gpghelper_print_error [PRINTF-FORMAT] ([ADDITIONAL-ARGS...])
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
_gpghelper_print_error() {
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
	printf '\e[31;1m(%s) Plugin error: \e[22m%s\e[0m\n' "${_GPGHELPER_PLUGIN_NAME}" "$(printf "${1}" ${@:2})" >&2
}

## * _gpghelper_print_query()
## _gpghelper_print_query - Prints a formatted question for querying user input.
##
## Usage: _gpghelper_print_query [MESSAGE]
##
## MESSAGE
## 	Header for the question, without colon.
_gpghelper_print_query() {
	# If -h|--help specified or no args provided, output help information.
	if [[ $# -eq 0 || $@ =~ '(^-h| -h|--help$|--help |^-[[:alnum:]]*h| -[[:alnum:]]*h)' ]]; then
		cat <<-EOF && return 0
			$funcstack[1] - Prints a formatted question for querying user input.

			Usage: $funcstack[1] [MESSAGE]

			MESSAGE
				Header for the question, without colon.
		EOF
	fi
	printf '\e[0;32;1m%s: \e[0;32;2m' "$1"
}

## * _gpghelper_input_query()
## _gpghelper_input_query - Query an input string from the user.
##
## Usage: _gpghelper_input_query [-p|--password]
##
##   -p|--password
##     Query the user for a password; User input won't be visibly printed.
_gpghelper_input_query() {
	# If -h|--help specified or no args provided, output help information.
	if [[ $# -eq 0 || $@ =~ '(^-h| -h|--help$|--help |^-[[:alnum:]]*h| -[[:alnum:]]*h)' ]]; then
		cat <<-EOF && return 0
			$funcstack[1] - Query an input string from the user.

			Usage: $funcstack[1] [-p|--password]

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

## * _gpghelper_input_validate()
## _gpghelper_input_validate - Query an input string from the user.
##
## Usage: _gpghelper_input_validate [INPUT] [VALIDATION_TYPE]
##
##   INPUT
##     Input string to validate.
##
##   VALIDATION_TYPE
##     Type to validate; Currently available: "name", "email".
_gpghelper_input_validate() {
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
