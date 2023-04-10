

#!/bin/bash

while getopts "p:r:k:d:c:f:" arg; do
  case $arg in
    p)    password=$OPTARG;;
    r)    relication_pwd=$OPTARG;;
    k)    kubectl=$OPTARG;;
    d)    docker=$OPTARG;;
    c)    kind=$OPTARG;;
    f)    force=$OPTARG;;
  esac
done

function install_docker {
    sudo apt-get update 
    sudo apt-get install -y curl ca-certificates git software-properties-common apt-transport-https
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
    apt-cache policy docker-ce
    sudo apt install docker-ce -y
    sudo usermod -aG docker ${USER} # add current user to docker gruop , to be able to execute docker commands 
    sudo systemctl enable docker   
}
function install_kubectl {
    sudo curl -fsSLo /etc/apt/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y kubectl
}
function install_kind {
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.18.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind    
}
if [ "${docker}" == "true" ] || [ "${force}" = "true" ]; then
    install_docker
fi
if [ "${kubectl}" == "true" ] || [ "${force}" = "true" ]; then
    install_kubectl
fi
if [ "${kind}" == "true" ] || [ "${force}" = "true" ]; then
    install_kind
fi
if [ -z "${password}" ]; then 
    echo "Please specify password for redis" 
    exit 1
fi
if [ -z "${relication_pwd}" ]; then 
    echo "Please specify password for redis replication" 
    exit 1
fi
kind create cluster --config cluster.yaml
kubectl get csr | awk '{if(NR>1)print $1}' | xargs  kubectl certificate approve
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml 
kubectl create ns web-app 
kubectl create ns redis
docker build -t go-lang-demo:latest go-app/. --no-cache
kind load docker-image go-lang-demo:latest
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
find redis/ -type f -print0 | xargs -0 sed -i '' -e "s/strong_password/${relication_pwd}/g"
find redis/ -type f -print0 | xargs -0 sed -i '' -e "s/your_password/${password}/g"
kubectl create secret generic redis-pwd --from-literal=password=${password} -n web-app
kubectl apply -f ingress-conf/ingress.yaml
kubectl apply -f ingress-conf/external-svc-golang.yaml
kubectl apply -f redis/fullconf.yaml
sleep 60
kubectl exec -it redis-0 -n redis -- sh -c \
 "redis-cli --cluster create redis-0.redis.redis.svc.cluster.local:6379 redis-1.redis.redis.svc.cluster.local:6379 redis-2.redis.redis.svc.cluster.local:6379 redis-3.redis.redis.svc.cluster.local:6379 redis-4.redis.redis.svc.cluster.local:6379 redis-5.redis.redis.svc.cluster.local:6379 -a ${password} --cluster-replicas 1 --cluster-yes"
 helm install web-app web-app/ -n web-app
echo "127.0.0.1    golang.k8s.local" >> /etc/hosts/
