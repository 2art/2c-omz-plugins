#!/usr/bin/env zsh

##==============================================================================
##== Configuration
##==============================================================================
#region Configuration

# Name of the plugin.
_GPGHELPER_PLUGIN_NAME="gpghelper"

# Array for possible GPG keyservers that can be accessed later in any scenario
_GPGHELPER_KEYSERVERS=(
  hkps://hkps.pool.sks-keyservers.net:443
	hkps://keyserver.pgp.com:443
  hkps://pgpkeys.eu:443
	hkps://pgp.mit.edu:443
  hkps://keys.openpgp.org:443
	hkps://keyserver.ubuntu.com:443
  hkps://pgp.mit.edu:443
)

# Default keyserver in case it's not specified somehow.
_GPGHELPER_DEFAULT_KEYSERVER="${_GPGHELPER_KEYSERVERS[1]}"

# Main keyserver to use in GPG aliases and functions.
export _GPGHELPER_KEYSERVER="${_GPGHELPER_KEYSERVER:-$_GPGHELPER_DEFAULT_KEYSERVER}"

# More commonly named export for possible other uses
export KEYSERVER="${_GPGHELPER_KEYSERVER}"

#endregion

##==============================================================================
##== GPG Aliases
##==============================================================================
#region GPG Aliases

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

#endregion

##==============================================================================
##== Public User Functions
##==============================================================================
#region Helper Functions

## * gpghelper_change_keyserver()
## Lists available keyservers in array at top of file, and lets user select the
## new keyserver to use this session.
gpghelper_change_keyserver() {
  printf '\e[32;1m0: \e[0;32;1;2m(Cancel)\e[0m\n'
  local i=1
  for addr in "${_GPGHELPER_KEYSERVERS[@]}"; do
    printf '\e[32;1m%d: \e[0;32;1;2m%s\e[0m\n' $((i++)) "$addr"
  done
  printf '\n\e[32;1mWhich keyserver to use?: '
  read num
  printf '\e[0m'
  if [[ ! $num =~ '^-?[0-9]+$' ]]; then
    _gpghelper_out_error "Selection '%s' is not a number." "$num"
    return 1
  elif (($num == 0)); then
    printf '\e[32;1mKeyserver remains as: \e[4m%s\e[0m\n' "${_GPGHELPER_KEYSERVER}"
    return 0
  elif (($num < 0 || $num > ${#_GPGHELPER_KEYSERVERS})); then
    _gpghelper_out_error "Selection '%d' is out of bounds." "$num"
    return 1
  else
    export _GPGHELPER_KEYSERVER="${_GPGHELPER_KEYSERVERS[$num]}"
    export KEYSERVER="${_GPGHELPER_KEYSERVERS[$num]}"
    printf '\e[32;1mNew keyserver for session: \e[4m%s\e[0m\n' "${_GPGHELPER_KEYSERVER}"
  fi
}

## * gpghelper_get_keyserver()
## Prints the keyserver that's currently active in this session.
gpghelper_get_keyserver() {
  printf '%s\n' "${_GPGHELPER_KEYSERVER}"
}

#endregion

##==============================================================================
##== Private Helper Functions
##==============================================================================
#region Private Helper Functions

## * _gpghelper_out_error()
## Prints an error including plugin name etc. to avoid confusion
##
## Usage: _gpghelper_out_error [PRINTF-FORMAT] ([ADDITIONAL-ARGS...])
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
_gpghelper_out_error() {
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

#endregion
