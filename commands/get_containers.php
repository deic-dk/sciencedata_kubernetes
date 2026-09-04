<?php

// curl '10.0.0.12/get_containers.php?user_id=fror@dtu.dk&pod_ip=10.2.x.y'

// We only allow requests from the silos
if(strpos($_SERVER['REMOTE_ADDR'], '10.0')!==0){
	header($_SERVER['SERVER_PROTOCOL'] . " 403 Forbidden", true, 403);
	exit;
}

$passwordFile = "/root/.get_containers_passwd";

function checkpassword($passwd){
	global $passwordFile;
	$pass = trim(file_get_contents($passwordFile));
	return ($pass===$passwd);
}

$_GET = array_map(function($x){return escapeshellcmd($x);}, $_GET);

$owner = empty($_GET['user_id'])&&!empty($pod_ip)?"none":$_GET['user_id']; // ID of the user logged into ScienceData
$password = empty($_GET['password'])?'':$_GET['password']; // Only used if user_id is empty
$fields = $_GET['fields']; // Get just the fields, the data or both fields and data
$pod_ip = $_GET['pod_ip']; // Get just one pod - used by sciencedata to check who owns the pod a given request is coming from

if(empty($owner)){
	if(!checkpassword($password)){
		header($_SERVER['SERVER_PROTOCOL'] . " 401 Unauthorized", true, 401);
		exit;
	}
}

if(!empty($pod_ip)){
	$pod_ip = " ".$pod_ip;
}

if(empty($fields) || $fields=="include"){
	echo `export KUBECONFIG=/etc/kubernetes/admin.conf; get_containers "${owner}"${pod_ip} 2>&1 | grep '|' | grep -v '^#'`;
}
elseif($fields=="yes" || $fields=="true"){// only fields 
	echo `export KUBECONFIG=/etc/kubernetes/admin.conf; get_containers "${owner}"${pod_ip} 2>&1 | head -2 | tail -1 | sed -E 's|^#||'`;
}
else{// fields=no , i.e. only values
	echo `export KUBECONFIG=/etc/kubernetes/admin.conf; get_containers "${owner}"${pod_ip}`;
}

?>
