#!/usr/bin/env bash
# Manage configurations for the ForgeRock platform. Copies configurations in git to the Docker/ folder
#    Can optionally export configuration from running products and copy it back to the git /config folder.
# This script is not supported by ForgeRock.
set -oe pipefail

## Start of arg parsing - originally generated by argbash.io
die()
{
	local _ret=$2
	test -n "$_ret" || _ret=1
	test "$_PRINT_HELP" = yes && print_help >&2
	echo "$1" >&2
	exit ${_ret}
}


begins_with_short_option()
{
	local first_option all_short_options='pch'
	first_option="${1:0:1}"
	test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}

# THE DEFAULTS INITIALIZATION - POSITIONALS
_positionals=()

# Profile defaults to cdk if not provided
_arg_profile="${_PROFILE:-obdemo-bank}"
_arg_environment="${_ENVIRONMENT:-dev}"
_arg_version="${_VERSION:-7.0}"
_arg_ig_mode=${_IGMODE:-development}
_IGMODES=(production development)

print_help()
{
	printf '%s\n' "manage ForgeRock platform configurations"
	printf 'Usage: %s [-p|--profile <arg>] [-c|--component <arg>] [-v|--version <arg>] [-h|--help] <operation>\n' "$0"
	printf '\t%s\n' "<operation>: operation is one of"
	printf '\t\t%s\n' "test   - Prints main script values"
	printf '\t\t%s\n' "init   - to copy initial configuration. This deletes any existing configuration in docker/"
	printf '\t\t%s\n' "add    - to add to the configuration. Same as init, but will not remove existing configuration"
	printf '\t\t%s\n' "diff   - to run the git diff command"
	printf '\t\t%s\n' "export - export config from running instance"
	printf '\t\t%s\n' "save   - save to git"
	printf '\t\t%s\n' "restore - restore git (abandon changes)"
	printf '\t\t%s\n' "sync   - export and save"
	printf '\t%s\n' "-p, --profile: Select configuration source (default: 'obdemo-bank')"
	printf '\t%s\n' "-e, --env: Select configuration environment source (default: 'dev')"
	printf '\t%s\n' "-igm, --igmode: Select configuration environment source values['production', 'development'(default)]"
	printf '\t%s\n' "-v, --version: Select configuration version (default: '7.0')"
	printf '\t%s\n' "-h, --help: Prints help"
	printf '\n%s\n' "example: config.sh -e dev -igm development init"
}


parse_commandline()
{
	_positionals_count=0
	while test $# -gt 0
	do
		_key="$1"
		case "$_key" in
			-p|--profile)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_profile="$2"
				shift
				;;
			--profile=*)
				_arg_profile="${_key##--profile=}"
				;;
			-p*)
				_arg_profile="${_key##-p}"
				;;
			-v|--version)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
			    _arg_version="$2"
				shift
				;;
			--version=*)
				_arg_version="${_key##--version=}"
				;;
			-v*)
				_arg_version="${_key##-v}"
				;;
			-h|--help)
				print_help
				exit 0
				;;
			-h*)
				print_help
				exit 0
				;;
		  -e|--env)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
			    _arg_environment="$2"
				shift
				;;
			--env=*)
				_arg_environment="${_key##--env=}"
				;;
			-e*)
				_arg_environment="${_key##-e}"
				;;
		  -igm|--igmode)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				modefounded="false"
        for v in "${_IGMODES[@]}"; do
          if [ "$2" == "$v" ]; then
            modefounded="true"
          fi
        done
          if [ "$modefounded" != "true" ]; then
            echo "ERROR: $2 isn't a valid value for the argument '$_key'."
            print_help
            exit 0
          fi
			    _arg_ig_mode="$2"
				shift
				;;
			--igmode=*)
				_arg_ig_mode="${_key##--igmode=}"
				;;
			-igm*)
				_arg_ig_mode="${_key##-igm}"
				;;
			*)
				_last_positional="$1"
				_positionals+=("$_last_positional")
				_positionals_count=$((_positionals_count + 1))
				;;
		esac
		shift
	done
}

handle_passed_args_count()
{
	local _required_args_string="'operation'"
	test "${_positionals_count}" -ge 1 || _PRINT_HELP=yes die "FATAL ERROR: Not enough positional arguments - we require exactly 1 (namely: $_required_args_string), but got only ${_positionals_count}." 1
	test "${_positionals_count}" -le 1 || _PRINT_HELP=yes die "FATAL ERROR: There were spurious positional arguments --- we expect exactly 1 (namely: $_required_args_string), but got ${_positionals_count} (the last one was: '${_last_positional}')." 1
}

assign_positional_args()
{
	local _positional_name _shift_for=$1
	_positional_names="_arg_operation "

	shift "$_shift_for"
	for _positional_name in ${_positional_names}
	do
		test $# -gt 0 || break
		eval "$_positional_name=\${1}" || die "Error during argument parsing, possibly an Argbash bug." 1
		shift
	done
}

parse_commandline "$@"
handle_passed_args_count
assign_positional_args 1 "${_positionals[@]}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || die "Couldn't determine the script's running directory, which probably matters, bailing out" 2

# End of arg parsing


# clear the product configs $1 from the docker directory.
clean_config()
{
    ## remove previously copied configs
    echo "removing $1 configs from $DOCKER_ROOT"

    if [ "$1" == "amster" ]; then
        rm -rf "$DOCKER_ROOT/$1/config"
    elif [ "$1" == "am" ]; then
	      rm -rf "$DOCKER_ROOT/$1/config"
    elif [ "$1" == "idm" ]; then
        rm -rf "$DOCKER_ROOT/$1/conf"
	      rm -rf "$DOCKER_ROOT/$1/script"
	      rm -rf "$DOCKER_ROOT/$1/ui"
    elif [ "$1" == "ig" ]; then
        rm -rf "$DOCKER_ROOT/$1/config"
        rm -rf "$DOCKER_ROOT/$1/scripts"
        rm -rf "$DOCKER_ROOT/$1/lib"
        rm -rf "$DOCKER_ROOT/$1/audit-schemas"
    fi
}

init_config()
{
  if [ -d "${PROFILE_ROOT}/$1" ]; then
    echo "*********************************************************************************************"
    echo "Initialisation of 'docker/7.0/$1' for [$_arg_environment] environment in [$_arg_ig_mode] mode"
    echo "*********************************************************************************************"
    echo "copy ${PROFILE_ROOT}/$1/audit-schemas to $DOCKER_ROOT/$1/"
    cp -r "${PROFILE_ROOT}/$1/audit-schemas" "$DOCKER_ROOT/$1/"
    echo "copy ${PROFILE_ROOT}/$1/lib to $DOCKER_ROOT/$1/"
    cp -r "${PROFILE_ROOT}/$1/lib" "$DOCKER_ROOT/$1/"
    echo "copy ${PROFILE_ROOT}/$1/scripts to $DOCKER_ROOT/$1/"
    cp -r "${PROFILE_ROOT}/$1/scripts" "$DOCKER_ROOT/$1/"
    echo "copy ${PROFILE_ROOT}/$1/secrets to $DOCKER_ROOT/$1/"
    cp -r "${PROFILE_ROOT}/$1/secrets" "$DOCKER_ROOT/$1/"
    echo "copy ${PROFILE_ROOT}/$1/config/$_arg_environment/config to $DOCKER_ROOT/$1/"
    cp -r "${PROFILE_ROOT}/$1/config/$_arg_environment/config" "$DOCKER_ROOT/$1/"
    jq --arg mode "$(echo $_arg_ig_mode | tr '[:lower:]' '[:upper:]')" '.mode = $mode' "$DOCKER_ROOT/$1/config/"admin.json > "$DOCKER_ROOT/$1/config/"admin.json.tmp
    mv "$DOCKER_ROOT/$1/config/"admin.json.tmp "$DOCKER_ROOT/$1/config/"admin.json
    echo "IG mode $_arg_ig_mode"
    if [ "$_arg_ig_mode" == "development" ]; then
      init_routes_dev "$1"
    else
      echo "copy ${PROFILE_ROOT}/$1/routes/ to $DOCKER_ROOT/$1/config"
      cp -r "${PROFILE_ROOT}/$1/routes/" "$DOCKER_ROOT/$1/config"
    fi
  fi
}

init_routes_dev(){
  echo "copy ${PROFILE_ROOT}/$1/routes/ to $DOCKER_ROOT/$1/config"
  if [ ! -d "$DOCKER_ROOT/ig-local/config/routes" ]; then
    echo "Creating the Directory $DOCKER_ROOT/$1/config/routes"
    mkdir "$DOCKER_ROOT/$1/config/routes"
  fi
  find "${PROFILE_ROOT}/$1/routes/"*/ -type f -print0 | xargs -0 -I {} cp {} "$DOCKER_ROOT/$1/config/routes/"
}

# Show the differences between the source configuration and the current Docker configuration
# Ignore dot files, shell scripts and the Dockerfile
# $1 - the product to diff
diff_config()
{
	for p in "${COMPONENTS[@]}"; do
		echo "diff  -u --recursive ${PROFILE_ROOT}/$p $DOCKER_ROOT/$p"
		diff -u --recursive -x ".*" -x "Dockerfile" -x "*.sh" "${PROFILE_ROOT}/$p" "$DOCKER_ROOT/$p" || true
	done
}

# Export out of the running instance to the docker folder
export_config(){
	for p in "${COMPONENTS[@]}"; do
	   # We dont support export for all products just yet - so need to case them
	   case $p in
		idm)
			printf "\nExporting IDM configuration...\n\n"
			rm -fr  "$DOCKER_ROOT/idm/conf"
			kubectl cp idm-0:/opt/openidm/conf "$DOCKER_ROOT/idm/conf"
			;;
		amster)
			printf "\nExporting Amster configuration...\n\n"
			printf "Skaffold is used to run the export job. Ensure your default-repo is set.\n\n"
			sleep 3

			rm -fr "$DOCKER_ROOT/amster/config"

			echo "Removing any existing Amster jobs..."
			kubectl delete job amster || true

			# Deploy Amster job
			echo "Deploying Amster job..."
			exp=$(skaffold run -p amster-export)

			# Check to see if Amster pod is running
			echo "Waiting for Amster pod to come up."
			while ! [[ "$(kubectl get pod -l app=amster --field-selector=status.phase=Running)" ]];
			do
					sleep 5;
			done
			printf "Amster job is responding..\n\n"

			pod=`kubectl get pod -l app=amster -o jsonpath='{.items[0].metadata.name}'`
			
			# Export OAuth2Clients and IG Agents
			echo "Executing Amster export within the amster pod"
			kubectl exec $pod -it /opt/amster/export.sh

			# Copy files locally
			echo "Copying the export to the ./tmp directory"

			# OBDEMO: copy whole realms directory, not just root realm subdir
			kubectl cp $pod:/var/tmp/amster/realms "$DOCKER_ROOT/amster/config"

			printf "Dynamic config exported\n\n"

			# Shut down Amster job
			printf "Shutting down Amster job...\n"

			del=$(skaffold delete -p amster-export)
			;;
		am)
			printf "\nExporting AM configuration..\n\n"

			pod=$(kubectl get pod -l app=am -o jsonpath='{.items[0].metadata.name}')

			kubectl exec $pod -- /home/forgerock/export.sh - | (cd "$DOCKER_ROOT"/am; tar xvf - )

			printf "\nAny changed configuration files have been exported into ${DOCKER_ROOT}/am/config."
			printf "\nCheck any changed files before saving back to the config folder to ensure correct formatting/functionality."
			;;
		*)
			echo "Export not supported for $p"
		esac
	done
}

# Save the configuration in the docker folder back to the git source
save_config()
{
	# Create the profile dir if it does not exist
	[[ -d "$PROFILE_ROOT" ]] || mkdir -p "$PROFILE_ROOT"

	for p in "${COMPONENTS[@]}"; do
		# We dont support export for all products just yet - so need to case them
		case $p in
		idm)
			printf "\nSaving IDM configuration..\n\n"
			# clean existing files
			rm -fr  "$PROFILE_ROOT/idm/conf"
			mkdir -p "$PROFILE_ROOT/idm/conf"
			cp -R "$DOCKER_ROOT/idm/conf"  "$PROFILE_ROOT/idm"
			;;
		amster)
			printf "\nSaving Amster configuration..\n\n"
			#****** REMOVE EXISTING FILES ******#
			rm -fr "$PROFILE_ROOT/amster/config"
			mkdir -p "$PROFILE_ROOT/amster/config"

			#****** FIX CONFIG RULES ******#

			# Fix FQDN and amsterVersion fields with placeholders. Remove encrypted password field.
			fqdn=$(kubectl get configmap platform-config -o yaml |grep AM_SERVER_FQDN | head -1 | awk '{print $2}')

			printf "\n*** APPLYING FIXES ***\n"

			echo "Adding back amsterVersion placeholder ..."
			echo "Adding back FQDN placeholder ..."
			echo "Removing 'userpassword-encrypted' fields ..."
			find "$DOCKER_ROOT/amster/config" -name "*.json" \
					\( -exec sed -i '' "s/${fqdn}/\&{ig.fqdn}/g" {} \; -o -exec true \; \) \
					\( -exec sed -i '' 's/"amsterVersion" : ".*"/"amsterVersion" : "\&{version}"/g' {} \; -o -exec true \; \) \
					-exec sed -i '' '/userpassword-encrypted/d' {} \; \

			# Fix passwords in OAuth2Clients with placeholders or default values.
			CLIENT_ROOT="$DOCKER_ROOT/amster/config/OAuth2Clients"
			IGAGENT_ROOT="$DOCKER_ROOT/amster/config/IdentityGatewayAgents"

			echo "Add back password placeholder with defaults"
			sed -i '' 's/\"userpassword\" : null/\"userpassword\" : \"\&{idm.provisioning.client.secret|openidm}\"/g' ${CLIENT_ROOT}/idm-provisioning.json
			sed -i '' 's/\"userpassword\" : null/\"userpassword\" : \"\&{idm.rs.client.secret|password}\"/g' ${CLIENT_ROOT}/idm-resource-server.json		
			sed -i '' 's/\"userpassword\" : null/\"userpassword\" : \"\&{ig.rs.client.secret|password}\"/g' ${CLIENT_ROOT}/resource-server.json
			sed -i '' 's/\"userpassword\" : null/\"userpassword\" : \"\&{pit.client.secret|password}\"/g' ${CLIENT_ROOT}/oauth2.json
			sed -i '' 's/\"userpassword\" : null/\"userpassword\" : \"\&{ig.agent.password|password}\"/g' ${IGAGENT_ROOT}/ig-agent.json

			#****** COPY FIXED FILES ******#
			cp -R "$DOCKER_ROOT/amster/config"  "$PROFILE_ROOT/amster"

			printf "\n*** The above fixes have been made to the Amster files. If you have exported new files that should contain commons placeholders or passwords, please update the rules in this script.***\n\n"
			;;
		*)
			printf "\nSaving AM configuration..\n\n"
			#****** REMOVE EXISTING FILES ******#
			rm -fr "$PROFILE_ROOT/am/config"
			mkdir -p "$PROFILE_ROOT/am/config"

			#****** COPY FIXED FILES ******#
			cp -R "$DOCKER_ROOT/am/config"  "$PROFILE_ROOT/am"
		esac
	done
}

# chdir to the script root/..
cd "$script_dir/.."
PROFILE_ROOT="config/$_arg_version/$_arg_profile"
DOCKER_ROOT="docker/$_arg_version"


# if [ "$_arg_component" == "all" ]; then
# COMPONENTS=(idm ig amster am)
# else
#	COMPONENTS=( "$_arg_component" )
# fi
# obdemo-bank only uses IG component
COMPONENTS=(ig)

case "$_arg_operation" in
test)
  echo "Environment: " $_arg_environment
  echo "Docker root: " $DOCKER_ROOT
  echo "Operation:" $1
  echo "Profile root: " ${PROFILE_ROOT}
  echo "Components: " ${COMPONENTS}
  ;;
init)
	for p in "${COMPONENTS[@]}"; do
		clean_config "$p"
		init_config "$p"
	done

	rm -rf docker/forgeops-secrets/forgeops-secrets-image/config
	mkdir -p docker/forgeops-secrets/forgeops-secrets-image/config

	echo "Copying version to version.sh"
	echo -n "CONFIG_VERSION=${_arg_version}" > docker/forgeops-secrets/forgeops-secrets-image/config/version.sh
	;;
add)
	# Same as init - but do not delete existing files.
	for p in "${COMPONENTS[@]}"; do
		init_config "$p"
	done
	;;
clean)
	for p in "${COMPONENTS[@]}"; do
		clean_config "$p"
	done
	;;
diff)
	diff_config
	;;
export)
	export_config
	;;
save)
	save_config
	;;
sync)
	export_config
	save_config
	;;
restore)
	git restore "$PROFILE_ROOT"
	;;
*)
	echo "Unknown command $_arg_operation"
esac
