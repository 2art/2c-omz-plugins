#!/usr/bin/env zsh

##======== Configuration & Variables ===========================================
#region Configuration & Variables

# Allowed signals. This was obtained from `kill -l` output. The pre-existing
# array "${signals}" contains a few more entries than this, but as they are
# invalid for use with 'pkill' or 'kill', I decided to drop them.
PROC_SIGNALS=(
	HUP INT QUIT ILL TRAP IOT BUS FPE KILL USR1 SEGV USR2 PIPE ALRM TERM STKFLT
	CHLD CONT STOP TSTP TTIN TTOU URG XCPU XFSZ VTALRM PROF WINCH POLL PWR SYS
)

# Set default signals for killproc() function. This variable can be modified
# externally (it is also exported below), in order to change default behavior.
KILLPROC_DEFAULT_SIGNALS=(
	KILL TERM HUP QUIT
)

# Export PROC_SIGNALS and KILLPROC_DEFAULT_SIGNALS because why not. Default
# signals can be modified, for example.
export -a PROC_SIGNALS
export -a KILLPROC_DEFAULT_SIGNALS

#endregion

##======== Main Functionality ==================================================
#region Main Functionality

## * killproc()
## Kills all processes by process name.
##
## Kills all processes by specified name, and optionally limiting to processes
## owned by specified UID. Attempts to send signal KILL first, by default,
## followed by TERM, HUP and QUIT if earlier ones don't work. The used signals
## can be modified when calling this function; Some signals can be excluded from
## the defaults, or whole signal list can be manually specified.
##
## USAGE:
##
##   killproc (-h|--help) [PROCESS_NAME] ([UID]) ([SIGNALS..])
##
## PARAMETERS:
##
##   [PROCESS_NAME]
##
##     Name of the process for searching PIDs with ´pgrep´. All processes by
##     this command name are searched and processed. NOTE: Command line
##     matching is not yet supported, only process command name.
##
##   [UID]
##
##     Optional user ID for ´pgrep -u UID -x PROCESS_NAME´. If not provided,
##     processes of every user are searched.
##
##   [SIGNALS..]
##
##     Optional string containing signals to send to found processes, with
##     values separated by comma. Don't prefix the signal with SIG-, only
##     include the main signal name. Signals can also be excluded by passing
##     a minus before the signal. Note that if any signal in the input list
##     has a minus sign, all signals listed must have one aswell.
##
##     Basically, this parameter can only be used to specify custom list of
##     signals, or to exclude signals from the default set.
##
##     By default, this value looks like: "KILL,TERM,HUP,QUIT"
##     Example value to skipping KILL:    "TERM,HUP,QUIT"
##     Example value to exclude KILL/HUP: "-KILL,-HUP"
##
## EXAMPLES:
##
##     # Show help information
##     killproc -h|--help
##
##     # Kill polybar process owned by cur user, with signals KILL,QUIT,INT
##     killproc polybar $UID KILL,QUIT,INT
##
##     # Kill processes named "sysprocess" and owned by UID 0 (root)
##     killproc sysprocess 0 KILL
##
##     # Try to kill all instances of 'someprog' with only KILL+TERM signals
##     killproc someprog -HUP,-QUIT
##
killproc() {
	# If -h|--help specified or no args provided, output help information.
	if [[ $# -eq 0 || $@ =~ '(^-h| -h|--help$|--help |^-[[:alnum:]]*h| -[[:alnum:]]*h)' ]]
	then
		cat <<-EOF | sed -E 's/\| /\t/g' && return 0
		$funcstack[1] - Kills all processes by process name.

    Kills all processes by specified name, and optionally limiting to processes
    owned by specified UID. Attempts to send signal KILL first, by default,
    followed by TERM, HUP and QUIT if earlier ones don't work. The used signals
    can be modified when calling this function; Some signals can be excluded
    from the defaults, or whole signal list can be manually specified.

		USAGE:

		| $funcstack[1] (-h|--help) [PROCESS_NAME] ([UID]) ([SIGNALS..])

		PARAMETERS:

		| [PROCESS_NAME]

		| | Name of the process for searching PIDs with ´pgrep´. All processes by
		| | this command name are searched and processed. NOTE: Command line
		| | matching is not yet supported, only process command name.

		| [UID]

		| | Optional user ID for ´pgrep -u UID -x PROCESS_NAME´. If not provided,
		| | processes of every user are searched.

		| [SIGNALS..]

		| | Optional string containing signals to send to found processes, with
		| | values separated by comma. Don't prefix the signal with SIG-, only
		| | include the main signal name. Signals can also be excluded by passing
		| | a minus before the signal. Note that if any signal in the input list
		| | has a minus sign, all signals listed must have one aswell.

		| | Basically, this parameter can only be used to specify custom list of
		| | signals, or to exclude signals from the default set.

		| | By default, this value looks like: "KILL,TERM,HUP,QUIT"
		| | Example value to skipping KILL:    "TERM,HUP,QUIT"
		| | Example value to exclude KILL/HUP: "-KILL,-HUP"

		EXAMPLES:

		| | # Show help information
		| | $funcstack[1] -h|--help

		| | # Kill polybar process owned by cur user, with signals KILL,QUIT,INT
		| | $funcstack[1] polybar $UID KILL,QUIT,INT

		| | # Kill processes named "sysprocess" and owned by UID 0 (root)
		| | $funcstack[1] sysprocess 0 KILL

		| | # Try to kill all instances of 'someprog' with only KILL+TERM signals
		| | $funcstack[1] someprog -HUP,-QUIT
		EOF
	fi

	local signals=(${KILLPROC_DEFAULT_SIGNALS[@]})  # Default signals in order of operation
	local procname=""  # Name of the process to search for with ´pgrep´
	local uid=-1       # If provided, only processes for this UID are searched
	local siglist=""   # Custom signal list or excluded signals

	# Process parameters.
	for arg in $@
	do
		# Check if variable is numeric, which means it should be interpreted as UID.
		if [[ $arg =~ '^[0-9]+$' ]]
		then
			uid=$arg
			continue
		fi

		# Check if argument begins with a dash, signifying signal exclusion or
		# multiple excludes, values separated by comma.
		if [[ $arg == -* ]]
		then
			# Split arg by comma and loop excludes from the input argument string,
			# making sure each start with a minus, after which, removing that minus to
			# check if the value is in the signals array. If so, remove it from the
			# array. If the exclude is not found in the array, throw error.
			for excl in $(sed -E 's|,|\n|g' <<< $arg)
			do
				# Make sure entry starts with a dash.
				if [[ $excl == -* ]]
				then
					excl="${excl#-}" # Remove dash from entry.
				else
					# Invalid entry; doesn't start with a dash like rest of the entries.
					printf '\e[31;1mError: \e[22mSignals in exclude list must all start with a dash.\e[0m\n' >&2
					return 1
				fi

				# Get the index position of current entry in signals array. If 0, entry
				# was not found in signals. If found, remove the signal from the array.
				if (( (pos=$(($signals[(I)$excl]))) != 0 ))
				then
					# Reset the index with target item; This removes it from the array
					signals[$pos]=()
				else
					# Signal is not in signals array and thus cannot be excluded.
					printf '\e[31;1mError: \e[22mSpecified signal to exclude is not in default signals: %s\e[0m\n' $excl >&2
					return 1
				fi
			done
			continue
		fi

		# Check if argument is a signal or multiple signals separated by comma, to
		# override default signals looped. Signals are always capitalized.
		if [[ $arg =~ '^([A-Z]+,)*[A-Z]+$' ]]
		then
			# Empty the default signals array. Split the argument into an array by
			# comma, and then loop the entry signals, validating each to be a valid
			# signal accepted by 'kill' and 'pkill', and then add it to signals array.
			# See the ${signals} array or 'kill -l' output for valid signals.
			signals=()
			for sig in $(sed -E 's|,|\n|g' <<< $arg)
			do
				# Check that this signal is in the PROC_SIGNALS array (containing all
				# valid signals). If not, throw an error.
				if (( (pos=$((${PROC_SIGNALS[(I)$sig]}))) > 0 ))
				then
					signals+=($sig)
				else
					printf '\e[31;1mError: \e[22mInvalid signal "%s"; See "kill -l" for a list of allowed values.\e[0m\n' $sig >&2
					return 1
				fi
			done
			continue
		fi

		# Argument is not NUM or SIGNALS, so it must be process name. Check that it's
		# a valid process name with no special characters.
		if [[ $arg =~ '^[[:alnum:]_-]+$' ]]
		then
			procname=$arg
			continue
		fi

		# Argument doesn't fit to any spot. It's a badly formatted process name, or
		# mistyped parameter for something else.
		printf '\e[31;1mError: \e[22mInvalid argument "%s" - Not a valid process name.\e[0m\n' "$arg" >&2
		return 1
	done

	# Final checks
	if [[ -z $procname ]]
	then
		# No valid process name was provided.
		printf '\e[31;1mError: \e[22mProcess name was not provided. Usage: ´%s [PROCESS_NAME] ([UID])´.\e[0m\n' $funcstack[1] >&2
		return 1
	fi

  # Initial PID scan to see if processes are found at all. If not, then the loop
  # afterwards is pointless.
	local pids=($(_killproc_get_pids $procname $uid))

	# If processes were found, loop signals and loop found process IDs for each
  # signal, until all found processes are dead.
  if (( $#pids > 0 ))
  then
    for signal in "${signals[@]}"
    do
      (( $#pids == 0 )) && break

      # Print separator line. Announce current signal processing start.
      printf '\e[36;1;2m%s\e[0m\n\n' "$(printf '=%.0s' {1..80})"
      printf '\e[32;1;2mNext signal: \e[0;32;1m%s\e[0m\n' $signal
      printf '\e[32;1;2mProcesses found: \e[0;32;1m%d\e[0m\n' $#pids

      # Output executed cmd (only one line with all PIDs, not each executed cmd)
      printf '\e[32;1;3m  >> kill -s %s {%s}\e[0m\n' $signal "${(j:, :)pids}"

      # Loop and pass current signal to each PID.
      for pid in ${pids[@]}
      do
        kill -s $signal $pid
      done

      # Sleep for a moment to allow processes to stop.
      sleep 0.5

      # Grep process again to get amount of matching processes still around.
      local postcount=$(_killproc_get_pids $procname $uid | wc -l)

      # Output amount of signals sent, and how many processes remain.
      printf '\e[32;1;2mProcesses terminated with signal \e[0;32;1m%s: %d/%d\e[0m\n' $signal $(($#pids - $postcount)) $#pids
      printf '\e[32;1;2mProcesses still remaining: \e[0;32;1m%d\e[0m\n\n' $postcount

      # Get PIDs again after previous kill calls.
      pids=($(_killproc_get_pids $procname $uid))
    done

    # Print final separator line.
    printf '\e[36;1;2m%s\e[0m\n\n' "$(printf '=%.0s' {1..80})"

    # Check if operation failed.
    local end_pids=($(_killproc_get_pids $procname $uid))
    if (( $#end_pids > 0 ))
    then
      printf '\e[31;1mFailed to kill all "%s" processes;\e[22m Remaining %d PIDs:\e[0m\n' $procname $#end_pids >&2
      printf '\t\e[31m%d\e[0m\n' ${end_pids[@]}
    fi
  fi
}

#endregion

##======== Private Helper Functions ============================================
#region Private Helper Functions

## * _killproc_get_pids()
## _killproc_get_pids - Get PIDs for a process using 'pgrep'.
##
## USAGE:
##   _killproc_get_pids [PROCESS_NAME] ([UID])
##
## PARAMETERS:
##   [PROCESS_NAME]: Name of the process to search using 'pgrep'.
##   [UID]: Optional for limiting the results to only processes owned by UID.
_killproc_get_pids() {
	# If -h|--help specified or no args provided, output help information.
	if [[ $# -eq 0 || $@ =~ '(^-h| -h|--help$|--help |^-[[:alnum:]]*h| -[[:alnum:]]*h)' ]]
	then
		cat <<-EOF | sed -E 's|\\ |\t|g' && return 0
		$funcstack[1] - Get PIDs for a process using 'pgrep'.

		USAGE:
		\ $funcstack[1] [PROCESS_NAME] ([UID])

		PARAMETERS:
		\ [PROCESS_NAME]: Name of the process to search using 'pgrep'.
		\ [UID]: Optional for limiting the results to only processes owned by UID.
		EOF
	elif [[ $# -gt 1 && $2 =~ '^[0-9]+$' && $2 -gt 0 ]]
	then
		pgrep -u $2 -x $1
	else
		pgrep -x $1
	fi
}

#endregion
