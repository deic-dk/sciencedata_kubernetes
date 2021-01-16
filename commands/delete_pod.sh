#!/bin/bash

# delete_pod.sh name

user=""
run=""

while getopts "u:d" flag; do
	case "$flag" in
		u)
			user=$OPTARG
			;;
		d)
			run="echo"
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

pod_name=${@:$OPTIND:1}
ssh_service_name="$pod_name-ssh"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# If user is given, check that user owns pod
if [ -n "$user" ]; then
	owner=`$DIR/get_containers.sh | grep "^$pod_name|" | awk -F'|' '{print $6}'`
	if [ "$owner" != "" && "$owner" != "$user" ]; then
		echo "ERROR: pod $pod_name owned by $owner, NOT $user" >&2
		exit 1
	fi
fi


# First find the IP of the pod
ip=`$DIR/get_containers.sh | grep "^$pod_name|" | awk -F'|' '{print $4}'`
# Kill reverse proxy
if [ -n "$ip" ]; then
	pid=`ps auxw | grep -v grep | grep -E "caddy reverse-proxy --from https://kube.sciencedata.dk:[0-9]+ --to $ip:80" | awk '{print $2}'`
	$run kill "$pid"
fi

$run kubectl delete service "$ssh_service_name"

### Clean up NFS storage claim, class, deployment

# Find claim name
claim_name=`kubectl get pod "$pod_name" -o json | jq -r '.spec.volumes[] | select(.name == "sciencedata") | .persistentVolumeClaim.claimName'`
$run kubectl delete pod "$pod_name"
if [ $claim_name ]; then
	# Check if others are using the claim
	while read line; do
		name=`echo $line | awk '{print $1}'`
		if ! [ $name ]; then
			continue
		fi
		claim=`kubectl get pod "$name" -o json | jq -r '.spec.volumes[] | select(.name == "sciencedata") | .persistentVolumeClaim.claimName'`
		if [ "$claim" == "$claim_name" ]; then
		  echo "Claim used by other pod $name" >&2
		  claim_active="yes"
		  break
		fi
	done < <( kubectl get pods | grep -Ev '^NAME ' | grep -Ev "^$pod_name" )
fi

if ! [ $claim_active ]; then
	# Find storage class name
	storage_class=`kubectl get persistentvolumeclaim "$claim_name" -o json | jq -r ".spec.storageClassName"`
	$run kubectl delete persistentvolumeclaim "$claim_name"
	# Check if storageclass is used by other claims
	while read line; do
		name=`echo $line | awk '{print $1}'`
		if ! [ $name ]; then
			continue
		fi
		class=`echo $line | awk '{print $7}'`
		if [ "$class" == "$storage_class" ]; then
		  echo "Storage class used by other claim" >&2
		  class_active="yes"
		  break
		fi
	done < <( kubectl get persistentvolumeclaims | grep -Ev '^NAME ' | grep -Ev "^$claim_name" )
fi

if ! [ $claim_active ] && ! [ $class_active ]; then
	# find nfs deployment name
	provisioner_name=`kubectl get storageclass "$storage_class" -o json | jq -r ".provisioner"`
	$run kubectl delete storageclass "$storage_class"
	# Check if deployment is used by other storage classes
	while read line; do
		name=`echo $line | awk '{print $1}'`
		if ! [ $name ]; then
			continue
		fi
		provisioner=`kubectl get storageclass "$name" -o json |  jq -r ".provisioner"`
		if [ "$provisioner" == "$provisioner_name" ]; then
		  echo "Deployment class used by other storage class" >&2
		  deployment_active="yes"
		  break
		fi
	done < <( kubectl get storageclasses | grep -Ev '^NAME ' | grep -Ev "^$storage_class" )
fi

if ! [ $claim_active ] && ! [ $class_active ]  && ! [ $deployment_active ]; then
	deployment_name=`kubectl get deployment -o json | jq -r ".items[] | select(.spec.template.spec.containers[].env[].name==\"PROVISIONER_NAME\") | select(.spec.template.spec.containers[].env[].value==\"$provisioner_name\") | .metadata.name"`
	$run kubectl delete deployment "$deployment_name"
fi

