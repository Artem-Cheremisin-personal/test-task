
# Requirements

## Simple to build and run
1. Verify that your instance has access to internet
2. Clone this repository
3. Run bash script **(autoconf.sh)** with needed flags
4. Better to use root user
>-p - password to connect to redis (required)

>-d - 'true' to install latest version of docker (optional)

>-r - password for replication nodes in redis (required)

>-k - 'true' to install latest version of kubectl (optional)

>-c 'true' to install latest version of kind (optional)

>-f - 'true' force installation for all needed packages (recomended for fresh VMs)

>example ```bash autoconf.sh -p yourpss -r replication pass -f true```

> access app though link http://golang.k8s.local:8080/id

## Application is able to be deployed on kubernetes and can be accessed from outside the cluster
1. Application automatically deploys to k8s cluster using kind(Kubernetes in docker) 
2. Cluster configuration could be found in 'cluster.yaml' file 
3. Cluster consist of 3 nodes. 1 master , 2 worker nodes. Í
4. Golang application uses helm chart to be deployed into cluster. Documentation could be found in web-app folder(README.md).  
5. Redis also automatically deploys to kind cluster using **redis cluster mode with replication enabled** it consists of 3 master 3 replica nodes.
## Application must be able to survive the failure of one or more instances while staying highly-available
1. Golang app uses **topologySpreadConstraints** key to be spread among nodes. 
2. Metric server is installed into cluster to provide ability golang application to scale on demand using **horizontal pod autoscaler**(just emulation not real data of CPU)
3. As I mentioned redis uses cluster mode that provides maximum highly-availablity.
4. Nginx ingress controler is single entrypoint that provides loadbalancing of application. 
> P.S. As far as we are using same intance to deploy all of aforementioned resources there is single point of failure. 
If istance goes down or internet connection - our product will go down as well.
# Redis must be password protected
1. Redis protected through acl + passwords.
2. Password for application is stored in k8s secrets.

# My vision of "highly-availabity" 
1. App should be deployed to at least 2 diffenent nodes in different "availability zone".
2. App should use HAproxy/cloud load balancer in front of ingress-controller.
3. Redis should be deployed to separate cluster with at least same configration as application.
4. App should communicate with redis internally(through private subnet).

# Few points 

1. I have changed a bit code of go app. It was not able to connect to redis(using cluster connection).
2. **Go-redis v8** library isn't capable with redis7, I've changed it to v9
3. Redis uses headless service to be able to commucate with replication nodes directly. 
4. zone label for nodes emulation of cross-zone deployment
5. **kind ingress** isn't able to obtain endpoints in different namespaces, that is the reason why **ExternalName** service is in place.
6. Usage of **serverTLSBootstrap: true** in nodes configuration - By default the kubelet serving certificate deployed by kubeadm is self-signed [k8s_doc](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/#kubelet-serving-certs)
# Improvemets
1. Cross-OS installation
2. No prompt on script execution
2. Helm chart for redis
3. Manual configuration of cluster
4. HAproxy
5. Separate clusters for redis and application 
