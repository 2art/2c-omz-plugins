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
