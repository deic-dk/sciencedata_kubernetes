# sciencedata_kubernetes

The ScienceData Kubernetes service allows ScienceData users to conveniently process data off their ScienceData storage.

- Pods/containers can be started directly from the ScienceData web interface
- A basic collection of pod manifests is provided
- Users can extend this, using the huge collection of image from Docker Hub
- Users can curl data directly from/to their ScienceData home directory over a trusted/direct connection w/o username/password
- Users can log in to their containers via SSH with their private SSH key after uploading their public key
- A website/service running on a pod, say "my-pod", on port 80 is inverse-proxied by https://kube.sciencedata.dk/my-pod/
- Persistent storage is mounted via NFSv4.1 from the ScienceData home server