<?php

// curl '10.0.0.12/get_containers.php?user_id=fror@dtu.dk'

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

$owner = $_GET['user_id']; // ID of the user logged into ScienceData
$password = empty($_GET['password'])?'':$_GET['password']; // Only used if user_id is empty
$fields = $_GET['fields']; // Get just the fields, the data or both fields and data

if(empty($owner)){
	if(!checkpassword($password)){
		header($_SERVER['SERVER_PROTOCOL'] . " 401 Unauthorized", true, 401);
		exit;
	}
}

if(empty($fields) || $fields=="include"){
	echo `export KUBECONFIG=/etc/kubernetes/admin.conf; get_containers "$owner" 2>&1 | grep '|' | grep -v '^#'`;
}
elseif($fields=="yes" || $fields=="true"){// only fields 
	echo `export KUBECONFIG=/etc/kubernetes/admin.conf; get_containers "$owner" 2>&1 | head -2 | tail -1 | sed -E 's|^#||'`;
}
else{// fields=no , i.e. only values
	echo `export KUBECONFIG=/etc/kubernetes/admin.conf; get_containers "$owner"`;
}

?>
