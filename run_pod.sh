#!/bin/bash

# run_pod.sh -o owner -k public_key 

EXTERNAL_IP=130.226.137.130
SERVICE_YAML_FILE="/root/ssh_service.yaml"

yaml_file=""
owner=""
ssh_public_key=""
dryrun=1

while getopts "o:k:d" flag; do
	case "$flag" in
		o)
			owner=$OPTARG
			;;
		k)
			ssh_public_key=$OPTARG
			;;
		d)
			dryrun=0
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			exit 1
		;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			exit 1
		;;
	esac
done

yaml_file=${@:$OPTIND:1}
#EXTRA_ARG=${@:$OPTIND+1:1}

if [ -z "$owner" ]; then
	echo "ERROR: Need owner"
	exit -1
fi

if [ -z "$ssh_public_key" ]; then
	# No ssh public key given on stdin, try getting it from env
	ssh_public_key="$SSH_PUBLIC_KEY"
	if [ -z "$ssh_public_key" ]; then
		# Try getting ssh public key from yaml
		ssh_public_key="`cat "$yaml_file" | yq -r '.spec.containers[]?.env[]? | select(.name == "SSH_PUBLIC_KEY") | .value'`"
		if [ -z "$ssh_public_key" ]; then
			echo "WARNING: No SSH public key - it will not be possible to log in"
		fi
	fi
fi

if [ -z "$yaml_file" ]; then
	echo "ERROR: Need input file"
	exit 1
fi

user=`echo $owner | awk -F@ '{print $1}'`
domain=`echo $owner | awk -F@ '{print $2}'`
owner=`echo $owner | sed 's|@|.|g' | sed 's|_|-|g'`

pod_name=`cat "$yaml_file" | yq -r .metadata.name | head -1`"-${owner}"

if [ -n "$pod_name" ]; then
	if [ "$dryrun" == "0" ]; then
		( cat $yaml_file | yq -r "(select(.spec.containers[]?.env[]?.name == \"SSH_PUBLIC_KEY\") | .spec.containers[].env[].value=\"$ssh_public_key\")"  | yq -r -y ".metadata.name=\"$pod_name\"" |\
		yq -r -y ".metadata.labels.user=\"$user\"" | yq -r -y ".metadata.labels.domain=\"$domain\"" |\
		yq -r -y ".metadata.labels.app=\"$pod_name\""
		echo "---"
		cat "$SERVICE_YAML_FILE"| yq -r -y ".spec.externalIPs=[\"$EXTERNAL_IP\"]" |\
		yq -r -y ".metadata.name=\"${pod_name}-ssh\"" | yq -r -y ".spec.selector={\"app\":\"$pod_name\"}") | \
		tee >(kubectl apply --validate=true --dry-run=client -f -)
	else
		( cat $yaml_file | yq -r  "(select(.spec.containers[]?.env[]?.name == \"SSH_PUBLIC_KEY\") | .spec.containers[].env[].value=\"$ssh_public_key\")"  | yq -r -y ".metadata.name=\"$pod_name\"" |\
		yq -r -y ".metadata.labels.user=\"$user\"" | yq -r -y ".metadata.labels.domain=\"$domain\""|\
		yq -r -y ".metadata.labels.app=\"$pod_name\""
		echo "---"
		cat "$SERVICE_YAML_FILE"| yq -r -y ".spec.externalIPs=[\"$EXTERNAL_IP\"]" |\
		yq -r -y ".metadata.name=\"${pod_name}-ssh\"" | yq -r -y ".spec.selector={\"app\":\"$pod_name\"}") | \
		kubectl apply -f -
	fi
else
	echo "ERROR: Parsing .metadata.name from YAML failed"
	exit 2
fi

# Forward port 22

# Run Caddy proxy to port 80
