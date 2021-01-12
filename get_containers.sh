#!/bin/bash

user="$@"

echo "###"
echo "pod_name|container_name|image_name|pod_ip|node_ip|owner|age(s)|status"
echo "###"
kubectl get pods -o json | jq -r '.items[].metadata.name' | while read pod; do
	podJson="`kubectl get pod "$pod" -o json`"
	hostip=`echo "$podJson" | jq -r '.status.hostIP'`
	podip=`echo "$podJson" | jq -r '.status.podIP'`
	#owner=`echo "$podJson" | jq -r '.metadata.labels | .user+"@"+.domain'`
	username=`echo "$podJson" | jq -r '.metadata.labels | .user'`
	domain=`echo "$podJson" | jq -r '.metadata.labels | .domain'`
	status=`echo "$podJson" | jq -r '.status.phase'`
	startTime=`echo "$podJson" | jq -r '.status.startTime'`
	startSeconds=`date -d "$startTime" +"%s"`
	nowSeconds=`date  +"%s"`
	diffSeconds=$((nowSeconds-startSeconds))
	if [ -n "$domain" ]; then
		owner="$username@$domain"
	else
		owner="$username"
	fi
	if [ -n "$user" -a "$user" != "$owner" ]; then
		continue
	fi
	kubectl get pod "$pod" -o json | jq -r --arg POD "$pod" --arg HOSTIP "$hostip" --arg PODIP "$podip" \
	--arg OWNER "$owner" --arg AGE "$diffSeconds" --arg STATUS "$status" \
	'.spec.containers[] | $POD+"|"+.name+"|"+.image+"|"+$PODIP+"|"+$HOSTIP+"|"+$OWNER+"|"+$AGE+"|"+$STATUS'
done | sed 's|@$||'

#kubectl label pod twocontainers domain=
#kubectl label pod twocontainers user=test