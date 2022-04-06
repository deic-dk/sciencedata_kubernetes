<?php

// curl '10.0.0.12/get_containers.php?user_id=fror@dtu.dk'

if(strpos($_SERVER['REMOTE_ADDR'], '10.0')!==0){
	header($_SERVER['SERVER_PROTOCOL'] . " 403 Forbidden", true, 403);
	exit;
}

$owner = $_GET['user_id']??""; // ID of the user logged into ScienceData
$fields = $_GET['fields']; // Get just the fields, the data or both fields and data

if(empty($fields) || $fields!="include" || $fields!="yes" || $fields!="true"){
	/*header($_SERVER['SERVER_PROTOCOL'] . " 403 Forbidden", true, 403);
	echo "<h1>Missing parameter(s)!</h1>";
	exit;*/
	echo `export KUBECONFIG=/etc/kubernetes/admin.conf; get_containers_testing "$owner" 2>&1 | grep '|' | grep -v '^#'`;
}
elseif($fields=="include"){
	echo `export KUBECONFIG=/etc/kubernetes/admin.conf; get_containers_testing "$owner"`;
}
else{// only fields - fields=yes or fields=true
	echo `export KUBECONFIG=/etc/kubernetes/admin.conf; get_containers_testing "$owner" 2>&1 | head -2 | tail -1 | sed -E 's|^#||'`;
}

?>