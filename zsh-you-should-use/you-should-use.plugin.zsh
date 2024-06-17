#!/bin/zsh

export YSU_VERSION='1.8.0'

if ! type "tput" > /dev/null; then
    printf "WARNING: tput command not found on your PATH.\n"
    printf "zsh-you-should-use will fallback to uncoloured messages\n"
else
    NONE="$(tput sgr0)"
    BOLD="$(tput bold)"
    DIM="$(tput dim)"
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"
    PURPLE="$(tput setaf 6)"
fi

check_alias_usage() {
    # Optional parameter that limits how far back history is checked
    # I've chosen a large default value instead of bypassing tail because it's simpler
    # TODO: this should probably be cleaned up
    local limit="${1:-9000000000000000}"
    local key

    declare -A usage
    for key in "${(@k)aliases}"; do
        usage[$key]=0
    done

    # TODO:
    # Handle and (&&) + (&)
    # others? watch, time etc...

    local current=0
    local total=$(wc -l < "$HISTFILE")
    if [[ $total -gt $limit ]]; then
        total=$limit
    fi

    local entry
    <"$HISTFILE" | tail "-$limit" | cut -d";" -f2 | while read line; do
        for entry in ${(@s/|/)line}; do
            # Remove leading whitespace
            # TODO: This is extremely slow
            entry="$(echo "$entry" | sed -e 's/^ *//')"

            # We only care about the first word because that's all aliases work with
            # (this does not count global and git aliases)
            local word=${entry[(w)1]}
            if [[ -n ${usage[$word]} ]]; then
                local prev=$usage[$word]
                let "prev = prev + 1 "
                usage[$word]=$prev
            fi
        done

        # print current progress
        let "current = current + 1"
        printf "Analysing: [$current/$total]\r"
    done
    # Clear all previous line output
    printf "\r\033[K"

    # Print ordered usage
    for key in ${(k)usage}; do
        echo "${usage[$key]}: $key='${aliases[$key]}'"
    done | sort -rn -k1
}

# Writing to a buffer rather than directly to stdout/stderr allows us to decide
# if we want to write the reminder message before or after a command has been executed
_write_ysu_buffer() {
    _YSU_BUFFER+="$@"

    # Maintain historical behaviour by default
    local position="${YSU_MESSAGE_POSITION:-before}"
    if [[ "$position" = "before" ]]; then
        _flush_ysu_buffer
    elif [[ "$position" != "after" ]]; then
        printf "${RED}${BOLD}Unknown value for YSU_MESSAGE_POSITION '$position'. ${NONE}" >&2
        printf "${RED}Expected value 'before' or 'after'${NONE}\n" >&2
        _flush_ysu_buffer
    fi
}

_flush_ysu_buffer() {
    # It's important to pass $_YSU_BUFFER to printfs first argument
    # because otherwise all escape codes will not printed correctly
    (>&2 printf "$_YSU_BUFFER")
    _YSU_BUFFER=""
}


# Prevent command from running if hardcore mode enabled
_check_ysu_hardcore() {
    if [[ "$YSU_HARDCORE" = 1 ]]; then
        _write_ysu_buffer "${RED}${BOLD}You Should Use hardcore mode enabled. Use your aliases!${NONE}\n"
        kill -s INT $$
    fi
}

function _check_git_aliases() {
    local typed="$1"
    local expanded="$2"

    # sudo will use another user's profile and so aliases would not apply
    if [[ "$typed" = "sudo "* ]]; then
        return
    fi

    if [[ "$typed" = "git "* ]]; then
        local found=false
        git config --get-regexp "^alias\..+$" | sort | while read key value; do
            key="${key#alias.}"

            # if for some reason, read does not split correctly, we
            # detect that and manually split the key and value
            if [[ -z "$value" ]]; then
                value="${key#* }"
                key="${key%% *}"
            fi

            if [[ "$expanded" = "git $value" || "$expanded" = "git $value "* ]]; then
              _add_to_aliases "git alias" "$value" "git $key"
              found=true
            fi
        done

        if $found; then
            _check_ysu_hardcore
        fi
    fi
}


function _check_global_aliases() {
    local typed="$1"
    local expanded="$2"

    local found=false
    local tokens
    local key
    local value
    local entry

    # sudo will use another user's profile and so aliases would not apply
    if [[ "$typed" = "sudo "* ]]; then
        return
    fi

    alias -g | sort | while IFS="=" read -r key value; do
        key="${key## }"
        key="${key%% }"
        value="${(Q)value}"

        # Skip ignored global aliases
        if [[ ${YSU_IGNORED_GLOBAL_ALIASES[(r)$key]} == "$key" ]]; then
            continue
        fi

        if [[ "$typed" = *" $value "* || \
              "$typed" = *" $value" || \
              "$typed" = "$value "* || \
              "$typed" = "$value" ]]; then

          _add_to_aliases "global alias" "$value" "$key"
          found=true
        fi
    done

    if $found; then
        _check_ysu_hardcore
    fi
}

_check_aliases() {
    local typed="$1"
    local expanded="$2"

    local found_aliases
    found_aliases=()
    local best_match=""
    local best_match_value=""
    local key
    local value

    # sudo will use another user's profile and so aliases would not apply
    if [[ "$typed" = "sudo "* ]]; then
        return
    fi

    # Find alias matches
    for key in "${(@k)aliases}"; do
        value="${aliases[$key]}"

        # Skip ignored aliases
        if [[ ${YSU_IGNORED_ALIASES[(r)$key]} == "$key" ]]; then
            continue
        fi

        if [[ "$typed" = "$value" || \
              "$typed" = "$value "* ]]; then

        # if the alias longer or the same length as its command
        # we assume that it is there to cater for typos.
        # If not, then the alias would not save any time
        # for the user and so doesn't hold much value anyway
        if [[ "${#value}" -gt "${#key}" ]]; then

            found_aliases+="$key"

            # Match aliases to longest portion of command
            if [[ "${#value}" -gt "${#best_match_value}" ]]; then
                best_match="$key"
                best_match_value="$value"
            # on equal length, choose the shortest alias
            elif [[ "${#value}" -eq "${#best_match}" && ${#key} -lt "${#best_match}" ]]; then
                best_match="$key"
                best_match_value="$value"
            fi
        fi
        fi
    done

    # Print result matches based on current mode
    if [[ "$YSU_MODE" = "ALL" ]]; then
      for key in ${(@ok)found_aliases}; do
          value="${aliases[$key]}"
          _add_to_aliases "alias" "$value" "$key"
      done
    elif [[ (-z "$YSU_MODE" || "$YSU_MODE" = "BESTMATCH") && -n "$best_match" ]]; then
        # make sure that the best matched alias has not already
        # been typed by the user
        value="${aliases[$best_match]}"
        [[ "$typed" = "$best_match" || "$typed" = "$best_match "* ]] && return
        _add_to_aliases "alias" "$value" "$best_match"
    fi

    if [[ -n "$found_aliases" ]]; then
        _check_ysu_hardcore
    fi
}

_print_possible_aliases() {
  if (( $#_YSU_ALS > 0 )); then
    printf "${BLUE}${BOLD}${UNDERLINE}Found aliases based on input command: ${NONE}\n"
    local -i longest=0
    # First find the longest alias type indicator (first item when split by :).
    for al in "${_YSU_ALS[@]}"; do
      echo $al | cut -d'|' -f1 | wc -m | read len
      if (( $len > $longest )); then
        longest=$len
      fi
    done
    # Now the indent value for the printf pattern is obtained; Print output
    for al in "${_YSU_ALS[@]}"; do
      echo $al | cut -d'|' -f1 | read altype
      echo $al | cut -d'|' -f2 | read inputcmd
      echo $al | cut -d'|' -f3 | read matchingal
      printf "${BLUE}${BOLD}${DIM}%${longest}s: ${NONE}${BLUE}${BOLD}%s ${NONE}${BLUE}${BOLD}-> ${NONE}${BLUE}${BOLD}%s${NONE}\n" "${altype}" "${inputcmd}" "${matchingal}"
      #_write_ysu_buffer "${al}"
    done
    printf '\e[0m\n'
    _YSU_ALS=()
  fi
}

# Add an alias that was found for the input command to the list of aliases to be
# printed in the precmd hook after command has ran successfully.
_add_to_aliases() {
  if (( $# >= 3 )); then
    _YSU_ALS+=( "$(printf '%s|%s|%s' $1 $2 $3)" )
  else
    printf "${RED}${BOLD}Error in plugin: '_add_to_aliases()' was called with $# parameters;${NONE}" >&2
    printf "${RED}3 parameters are required: 1: Alias Type, 2: Input Command, and 3: Found Matching Alias.${NONE}" >&2
    return 1
  fi
}

# Disable the you_should_use_2art plugin.
disable_you_should_use_2art() {
    add-zsh-hook -D preexec _check_aliases
    add-zsh-hook -D preexec _check_global_aliases
    add-zsh-hook -D preexec _check_git_aliases
    add-zsh-hook -D preexec _print_possible_aliases
    add-zsh-hook -D precmd _flush_ysu_buffer

}

# Enable the you_should_use_2art plugin.
enable_you_should_use_2art() {
    disable_you_should_use_2art   # Delete any possible pre-existing hooks
    add-zsh-hook preexec _check_aliases
    add-zsh-hook preexec _check_global_aliases
    add-zsh-hook preexec _check_git_aliases
    add-zsh-hook preexec _print_possible_aliases
    add-zsh-hook precmd _flush_ysu_buffer
}


autoload -Uz add-zsh-hook
enable_you_should_use_2art
