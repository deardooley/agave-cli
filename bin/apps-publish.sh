#!/bin/bash
# 
# apps-delete
# 
# author: dooley@tacc.utexas.edu
#
# This script is part of the Agave API command line interface (CLI).
# It performs a management action on an app such as publication or
# cloning.
#

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$DIR/common.sh"

hosturl="$baseurl/apps/"
storetoken=0

# Script logic -- TOUCH THIS {{{

# A list of all variables to prompt in interactive mode. These variables HAVE
# to be named exactly as the longname option definition in usage().
interactive_opts=(apisecret apikey action)

# Print usage
usage() {
  echo -n "$(basename $0) [OPTION]... [APP_ID]

Description of this script.

 Options:
  -s, --apisecret   API secret for authenticating
  -k, --apikey      API key for authenticating, its recommended to insert
                    this through the interactive option
  -a, --action      Action to perform: publish or clone. Admin privileges 
                    required for publishing.
  -H, --hosturl     URL of the service
  -d, --development Run in dev mode using default dev server
  -f, --force       Skip all user interaction
  -i, --interactive Prompt for values
  -q, --quiet       Quiet (no output)
  -v, --verbose     Output more
  -h, --help        Display this help and exit
      --version     Output version information and exit
"
}

##################################################################
##################################################################
#						Begin Script Logic						 #
##################################################################
##################################################################

main() {
	#echo -n
	#set -x
	
	if [ -z "$args" ]; then
		err "Please specify a valid app id on which to operate"
	else
		
		if [ "publish" != "$action" ]; then
			if [ "clone" != "$action" ]; then
				err "Please specify a valid action. Valid actions are 'publish' and 'clone'"
			fi
		fi
		
		cmd="curl -sku \"$apisecret:XXXXXX\" -X PUT \"action=$action\" $hosturl$args"

		log "Calling $cmd"
	
		response=`curl -sku "$apisecret:$apikey" -X PUT "action=$action" "$hosturl$args"`

		jsonval response_status "$response" "status"

		if [ "$response_status" = "success" ]; then
			format_api_json "$response"
		else
			jsonval response_message "$response" "message" 
			err "$response_message"
		fi
	fi	
}

format_api_json() {

	jsonval app_id "$1" "id" 
	
	if ((verbose)); then
		echo "$1" | python -mjson.tool
	else
		if [ "publish" != "$action" ]; then
			success "Successfully published app $args as $app_id"
		else
			success "Successfully cloned app $args to $app_id"
		fi
	fi
}

##################################################################
##################################################################
#						End Script Logic						 #
##################################################################
##################################################################

# }}}
# Boilerplate {{{

# Iterate over options breaking -ab into -a -b when needed and --foo=bar into
# --foo bar
optstring=h
unset options
while (($#)); do
  case $1 in
  	# If option is of type -ab
    -[!-]?*)
      # Loop over each character starting with the second
      for ((i=1; i < ${#1}; i++)); do
      	c=${1:i:1}
		
        # Add current char to options
        options+=("-$c")

        # If option takes a required argument, and it's not the last char make
        # the rest of the string its argument
        if [[ $optstring = *"$c:"* && ${1:i+1} ]]; then
          options+=("${1:i+1}")
          break
        fi
      done
      ;;
    # If option is of type --foo=bar
    --?*=*) options+=("${1%%=*}" "${1#*=}") ;;
    # add --endopts for --
    --) options+=(--endopts) ;;
    # Otherwise, nothing special
    *) options+=("$1") ;;
  esac
  shift
done
set -- "${options[@]}"
unset options

# Set our rollback function for unexpected exits.
trap rollback INT TERM EXIT

# A non-destructive exit for when the script exits naturally.
safe_exit() {
  trap - INT TERM EXIT
  exit
}

# }}}
# Main loop {{{

# Print help if no arguments were passed.
[[ $# -eq 0 ]] && set -- "-i"

# Read the options and set stuff
while [[ $1 = -?* ]]; do
  case $1 in
    -h|--help) usage >&2; safe_exit ;;
    --version) out "$(basename $0) $version"; safe_exit ;;
    -s|--apisecret) shift; apisecret=$1 ;;
    -k|--apikey) shift; apikey=$1 ;;
    -a|--action) shift; action=$1 ;;
    -H|--hosturl) shift; hosturl=$1;;
  	-d|--development) development=1 ;;
    -v|--verbose) verbose=1 ;;
    -q|--quiet) quiet=1 ;;
    -i|--interactive) interactive=1 ;;
    -f|--force) force=1 ;;
    --endopts) shift; break ;;
    *) die "invalid option: $1" ;;
  esac
  shift
done

# Store the remaining part as arguments.
args+=("$@")

# }}}
# Run it {{{

# Uncomment this line if the script requires root privileges.
# [[ $UID -ne 0 ]] && die "You need to be root to run this script"

if ((!local)); then 
	if [ -z "$apikey" ]; then
		interactive=1
	fi

	if [ -z "$apisecret" ]; then
		interactive=1
	fi
fi

if ((interactive)); then
  prompt_options
fi

# You should delegate your logic from the `main` function
main

# This has to be run last not to rollback changes we've made.
safe_exit

# }}}
