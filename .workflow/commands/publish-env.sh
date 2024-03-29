#!/usr/bin/env bash

. .workflow/global.sh || exit 1


if [  $# -le 0 ]
then
	echo $cyan"Publish Environment v1.0"$white
	echo
    echo -e "Publish the local development project to a remote server, the target can be either staging|production"
    echo
    echo "It is assumed that the target has the following actions complete:"
    echo "    - SSH access to target server"
    echo "    - Wordpress CLI installed on target server"
    echo "    - Defined target url/user/host/path in config.conf"
    echo "    - Working directory setup on target server"
    echo "    - Database created on target server"
    echo "    - wp-config-<target>.php created with target db credentials"
    exit 1
fi


echo $cyan'Preparing to publish...'$white
echo
echo 'Target is:' $1;
echo

TARGET=$1


# Check destination is allowed
if [ "$TARGET" == "dev" ]
then
	echo $red"Error!"$white "Publish target can only be either staging|production"

	exit 1
fi


# Check publish hasn't already been ran for the requested environment
check_launch_env() {

	wp_cli_source="@$TARGET"

	if $(wp $wp_cli_source core is-installed); then
		echo $red"Error!"$white "$TARGET environment is already installed..."

		exit 1
	fi
}

check_launch_env


REMOTE_LOCATION=$(get_host $TARGET)


# Sync all files to the target environment
rsync -avz --exclude-from "$(pwd)/.workflow/exclude/publish-$TARGET.txt" --include=".htaccess" * "$REMOTE_LOCATION"


setup_target_wp_config() {

	local host="$(get_host $TARGET)"

	case "$TARGET" in
		"staging" )
			local remote_path="$STAGING_PATH"
		;;
		"production" )
			local remote_path="$PRODUCTION_PATH"
		;;
		* )
			echo "Invalid target: $env"; exit 1
		;;
	esac

	if [[ -z $remote_path ]]
	then
		echo "Remote path for $env could not be resolved..."
		exit 1
	fi

	ssh $(get_host $TARGET "root") "

		cd $( echo "$remote_path" );

		mv wp-config-\"$TARGET\".php wp-config.php;

        wp db create;
	"
}

setup_target_wp_config


# Move the database
. .workflow/commands/sync-db.sh dev $TARGET


# Do further production publish
prep_production_publish() {

	wp @production plugin install wordfence --activate
	wp @production plugin install wp-fastest-cache
}

if [[ "$TARGET" == "production" ]]
then
	prep_production_publish
fi

