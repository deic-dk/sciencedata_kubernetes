#!/bin/bash

#
# Report running time this month (since the same day of month last month)
# for specific pod (on deletion) or all pods (monthly)
# This script is run with -p by delete_pod or without -p but with -u by a monthly cronjob.
# This cronjob must run before the accounting cronjob on the silos. These run at night,
# so noon is probably a good time.
#

user=""
run=""
logfile="/var/log/kube.log"
TMPDIR="/tmp"
# Fallback billing day of month
BILLING_DAY=26
# URL to get billing day of month - to be sure to use the same as on the billing end
BILLING_DAY_URL="https://sciencedata.dk/apps/files_accounting/billingday.php"

billingday=`curl BILLING_DAY_URL`
if [ -n "$billingday" ]; then
  BILLING_DAY=$billingday
fi

terminating=1
while getopts "u:p:td" flag; do
	case "$flag" in
		u)
			user=$OPTARG
			;;
    p)
      pod_name=$OPTARG
      ;;
    t)
      terminating=0
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

DIR="$(dirname "$(readlink -f "$0")")"

if [[ -z "$user" && -n "$pod_name" ]]; then
  user=`kubectl get pod/$pod_name -o json | jq -r '.spec.containers[].env[] | select(.name=="SD_UID") | .value'`
fi

home_server=`kubectl get pod/$pod_name -o json | jq -r '.spec.containers[].env[] | select(.name=="HOME_SERVER") | .value'`

if [[ -z "$user" ]]; then
  echo "Need user" >2
  exit 100
fi
if [[ -z "$user" || -z "$home_server" ]]; then
  echo "Need home server" >2
  exit 100
fi

accounting_endpoint="$home_server/apps/files_accounting/report_pod_usage.php"

# Report on specific pod to home silo
usage_report() {
  line="$0"
  ## pod_name|container_name|image_name|pod_ip|node_ip|owner|age|status|ssh_port|ssh_username|https_port|uri
  ## user node_name node_ip pod_name pod_ip start_time end_time running_seconds
  node_ip=${line[4]}
  image_name=${line[2]}
  pod_name=${line[0]}
  pod_ip=${line[3]}
  node_name=`$kubectl get nodes -o wide | grep " $node_ip " | awk '{print $1}'`
  now_seconds=`date +"%s"`
  month=`date +%b`
  month_no=`date +%m`
  year=`date +%Y`
  last_month=`date --date="$(date +%Y-%m-15) -1 month" +'%b'`
  now_day_no=`date +%d`
  if [ $now_day_no >= $BILLING_DAY ]; then
    last_billing_date=`date --date="$(date +%Y-%m-$BILLING_DAY)"`
  else
    last_billing_date=`date --date="$(date +%Y-$last_month-$BILLING_DAY)"`
  fi
  last_billing_seconds=`date --date="$last_billing_date" +"%s"`
  billing_period_till_now_seconds=$((now_seconds - last_billing_seconds))
  age=${line[6]}
  if [[ $age > $billing_period_till_now_seconds ]]; then
    running_seconds=$billing_period_till_now_seconds
  else
    running_seconds=$age
    # start_time only set if started in this billing period
    start_time=$((now_seconds - age))
  fi
  if [[ "$terminating" == "0" ]]; then
    end_time=$now_seconds
  fi
  # POST the data
  curl --data "user=$user&node_name=$node_name&image_name=$image_name&node_ip=$node_ip&pod_name=$pod_name&pod_ip=$pod_ip&start_time=$start_time&end_time=$end_time&running_seconds=$running_seconds&year=$year&month=$month_no&day=$now_day_no&cycle_day=$BILLING_DAY" "$accounting_endpoint"
}

if [[ -n "$pod_name" ]]; then
  # Specific pod
  readarray -d '|' -t podInfo < <($DIR/get_containers $user | grep "^$pod_name|")
  usage_report podInfo
else
  # All owned pods
  get_containers $user | while read line; do
    readarray -d '|' -t podInfo < <( echo "$line" );
    usage_report podInfo
  done
fi

exit 0


