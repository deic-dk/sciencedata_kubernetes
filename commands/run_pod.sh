#!/bin/bash

# run_pod.sh -o owner -k public_key yaml_file

EXTERNAL_IP=130.226.137.130
SCIENCEDATA_WS_IP=10.0.0.13
SSH_SERVICE_YAML_FILE="/root/sciencedata_kubernetes/ssh_service.yaml"
NFS_DEPLOYMENT_YAML_FILE="/root/sciencedata_kubernetes/nfs_deployment.yaml"
NFS_CLASS_YAML_FILE="/root/sciencedata_kubernetes/nfs_class.yaml"
NFS_CLAIM_YAML_FILE="/root/sciencedata_kubernetes/nfs_claim.yaml"

yaml_file=""
owner=""
ssh_public_key=""
# Path on home server to be claimed, relative to /tank/storage/owner/
# Notice that the mountpoint is specified in the pod yaml
storage_path=""
dryrun=

while getopts "o:k:p:d" flag; do
	case "$flag" in
		o)
			owner=$OPTARG
			;;
		k)
			ssh_public_key=$OPTARG
			;;
		p)
			storage_path=$OPTARG
			;;
		d)
			dryrun="yes"
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
	echo "ERROR: Need owner"  >&2
	exit -1
fi
\"
# Check if the user is attempting an NFS volume deployment (mount)
grep -iE 'kind: *Deployment' "$yaml_file"
if [ $? -eq 0 ]; then
	echo "ERROR: Manual mounts are not allowed" >&2
	exit -2
fi

# Check if there's an NFS persistentVolumeClaim claim in the pod yaml
grep -E '^ claimName: sciencedata-nfs-claim' "$yaml_file"
if [ "$?" -eq "0" ]; then
	echo "ERROR: Manual claims are not allowed" >&2
	exit -3
fi

if [ -z "$ssh_public_key" ]; then
	# No ssh public key given on stdin, try getting it from env
	ssh_public_key="$SSH_PUBLIC_KEY"
	if [ -z "$ssh_public_key" ]; then
		# Try getting ssh public key from yaml
		ssh_public_key="`cat "$yaml_file" | yq -r '.spec.containers[]?.env[]? | select(.name == "SSH_PUBLIC_KEY") | .value'`"
		if [ -z "$ssh_public_key" ]; then
			echo "WARNING: No SSH public key - it will not be possible to log in" >&2
		fi
	fi
fi

if [ -z "$yaml_file" ]; then
	echo "ERROR: Need input file" >&2
	exit 1
fi

user=`echo $owner | awk -F@ '{print $1}'`
domain=`echo $owner | awk -F@ '{print $2}'`
owner_str=`echo $owner | sed 's|[@._]|-|g'`

pod_name=`cat "$yaml_file" | yq -r .metadata.name | head -1`"-${owner_str}"

if [ -n "$storage_path" ]; then
	# Check if there's an NFS deployment for the home server of $owner
	home_server=`curl --insecure "https://$SCIENCEDATA_WS_IP/apps/files_sharding/ws/get_user_server.php?user_id=$owner&internal=yes" | sed 's|\\/|/|g' | jq -r '.url' | grep -E 'https*://' | sed -E 's|^https*://||'`
	if [ $home_server ]; then
		kubectl get deployment | grep "nfs-client-provisioner-${home_server}"
		if [ "$?" -ne "0" ]; then
			deploy_nfs="yes"
		fi
		kubectl get storageclass | grep "managed-nfs-storage-${home_server}"
		if [ "$?" -ne "0" ]; then
			create_nfs_class="yes"
		fi
		# Check if a claim has already been made on $storage_path
		kubectl get PersistentVolumeClaim | grep  "sciencedata-nfs-claim-${owner_str}-${storage_path}"
		if [ "$?" -ne "0" ]; then
			claim_nfs="yes"
		fi
	fi
fi

if [ -n "$pod_name" ]; then
	### Modify pod YAML - ssh public key, metadata, volume
	( cat $yaml_file | yq -r "(select(.spec.containers[]?.env[]?.name == \"SSH_PUBLIC_KEY\") | .spec.containers[].env[].value=\"$ssh_public_key\")"  | yq -r -y ".metadata.name=\"$pod_name\"" |\
	yq -r -y ".metadata.labels.user=\"$user\"" | yq -r -y ".metadata.labels.domain=\"$domain\"" |\
	yq -r -y ".metadata.labels.app=\"$pod_name\"" | \
	( [ -z "$storage_path" ] && cat || yq -r -y ".spec.volumes=[{\"name\":\"sciencedata\", \"persistentVolumeClaim\": {\"claimName\": \"sciencedata-nfs-claim-$owner_str-$storage_path\"}}]")
	### SSH service
	echo "---"
	cat "$SSH_SERVICE_YAML_FILE"| yq -r -y ".spec.externalIPs=[\"$EXTERNAL_IP\"]" |\
	yq -r -y ".metadata.name=\"${pod_name}-ssh\"" | yq -r -y ".spec.selector={\"app\":\"$pod_name\"}"
	if [ -n "$storage_path" ]; then
		### NFS deployment
		if [ $create_nfs_class ]; then
			echo "---"
			cat "$NFS_DEPLOYMENT_YAML_FILE" | sed "s|SERVER_IP|$home_server|g" | sed "s|NFS_DEPLOYMENT_NAME|nfs-client-deployment-${home_server}|" | \
			sed "s|SCIENCEDATA_PROVISIONER|sciencedata-provisioner-${home_server}|"
		fi
		### NFS class
		if [ $deploy_nfs ]; then
			echo "---"
			cat "$NFS_CLASS_YAML_FILE" | sed "s|NFS_STORAGE_CLASS_NAME|managed-nfs-storage-${home_server}|g" | \
			sed "s|SCIENCEDATA_PROVISIONER|sciencedata-provisioner-${home_server}|"
		fi
		### NFS persistent volume claim
		if [ $claim_nfs ]; then
			echo "---"
			cat "$NFS_CLAIM_YAML_FILE" | sed "s|STORAGE_PATH|$storage_path|g" | \
			sed -E "s|NFS_CLAIM_NAME|sciencedata-nfs-claim-${owner_str}-${storage_path}|" | \
			sed "s|NFS_STORAGE_CLASS_NAME|managed-nfs-storage-${home_server}|"
		fi
	fi
	) | tee >([ -z "$dryrun" ] && kubectl apply -f - || kubectl apply --validate=true --dry-run=client -f -)
else
	echo "ERROR: Parsing .metadata.name from YAML failed" >&2
	exit 2
fi

if [ -z "$dryrun" ]; then
	# Run Caddy proxy to port 80
	# First find free port in range 2000-2100
	for i in {2000..2100}; do ps auxw | grep -v grep | grep "caddy reverse-proxy" | grep -v "caddy reverse-proxy --from https://kube.sciencedata.dk:$i" >& /dev/null && break; done
	# Run reverse proxy
	caddy reverse-proxy --from https://kube.sciencedata.dk:$i --to 10.2.0.50:80 >& /dev/null &
fi


