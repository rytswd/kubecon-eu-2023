#!/usr/bin/env bash
# shellcheck disable=SC2016

###
### NOTE:
###
### This file is simply concatenated version of other scripts for running demo from curl.
###

# shellcheck disable=SC2034
demo_helper_type_speed=5000


# 📌 Original file at:
#    https://github.com/rytswd/cli-demo-helper

###---- ⬇️ HOW TO USE ⬇️ ---------------------------------------------------###
#
#  Simply source this file to import functions, and use them like:
#
#      comment "This is a comment! About to start command..."
#      execute "ls -la"
#
#  You can configure speed, prompt, etc.
#  For more information, please check out:
#      https://github.com/rytswd/cli-demo-helper
#

###---- ⬇️ SETUP ⬇️ --------------------------------------------------------###

# Colour setup
__reset=$(tput sgr0)
__red=$(
    tput bold
    tput setaf 1
)
__green=$(
    tput bold
    tput setaf 2
)
__blue=$(
    tput bold
    tput setaf 6
)
__yellow=$(
    tput bold
    tput setaf 3
)
__white=$(
    tput bold
    tput setaf 7
)
readonly reset=$__reset
readonly red=$__red
readonly green=$__green
readonly blue=$__blue
readonly yellow=$__yellow
readonly white=$__white

# Speed
type_speed=${demo_helper_type_speed:="1200"} # In characters per min notation
interval="100"                               # In ms

# Prompt
prompt=${demo_helper_prompt:="$yellow$ $reset"}

###---- ⬇️ EXTRA CONFIGURATION ⬇️ ------------------------------------------###

# TBD

###---- ⬇️ Internal Prep ⬇️ ------------------------------------------------###
sleep_duration=$(echo "scale=2 ; 60 / $type_speed" | bc)

# type_out imitates typing out the provided string
function type_out() {
    s=$*
    while [ ${#s} -gt 0 ]; do
        printf '%.1s' "$s"
        s=${s#?}
        sleep "$sleep_duration"
    done
}

# write_prompt writes PS1 like prompt
function write_prompt() {
    echo -n "$prompt"
}

###---- ⬇️ MAIN FUNCTIONS ⬇️ -----------------------------------------------###
function clear_terminal() {
    clear
    write_prompt
}

# comment writes hash and then any content as comment
function comment() {
    echo -n "$blue# "
    type_out "$*"
    echo " $reset"
    write_prompt
    read -rs
}
# comment_r writes comment in red
function comment_r() {
    echo -n "$red# "
    type_out "$*"
    echo " $reset"
    write_prompt
    read -rs
}
# comment_g writes comment in green
function comment_g() {
    echo -n "$green# "
    type_out "$*"
    echo " $reset"
    write_prompt
    read -rs
}
# comment_b writes comment in blue
function comment_b() {
    echo -n "$blue# "
    type_out "$*"
    echo " $reset"
    write_prompt
    read -rs
}

# comment_w writes comment in white
function comment_w() {
    echo -n "$white# "
    type_out "$*"
    echo " $reset"
    write_prompt
    read -rs
}

function execute() {
    type_out "$*"
    read -rs
    echo

    eval "$*"
    r=$?

    echo
    write_prompt
    read -rs
    return $r
}

# Ensure the process starts with some prompt
write_prompt

trap "echo" EXIT

comment_w "Welcome to the demo!

This script will walk you through the demo steps.
Simply wait for the prompt to appear, and press enter to continue.

Firstly, we will start with extra steps of local cluster configurations.
If you would like to use your own clusters, please refer to https://github.com/rytswd/kubecon-eu-2023 repository."


comment_g "Ex 1. Create temporary directory."
execute "mkdir /tmp/kubecon-mco-demo; cd /tmp/kubecon-mco-demo"
comment "Ex 1.1. Copy the demo repository."
execute 'curl -sSL https://codeload.github.com/rytswd/kubecon-eu-2023/tar.gz/main \
    -o kubecon-eu-2023.tar.gz'

comment_g "Ex 2. Create KinD clusters."
comment "Ex 2.1. Get KinD configs specific for the demo."
execute 'tar -xz -f kubecon-eu-2023.tar.gz \
    --strip=2 kubecon-eu-2023-main/tools/kind-config'

DOCKER_NETWORK_CIDR=$(docker network inspect kind | jq -r ".[].IPAM.Config[0].Subnet")

comment_r "NOTE:"
comment_w "Based on your Docker network setup, you will need to update the following files:
    - /tmp/kubecon-mco-demo/kind-config/cluster-1-v1.26.yaml
    - /tmp/kubecon-mco-demo/kind-config/cluster-2-v1.26.yaml
    - /tmp/kubecon-mco-demo/kind-config/cluster-3-v1.26.yaml

    In each file, ensure that kubeadmConfigPatches -> apiServer -> certSANs matches with the following CIDR:

    $DOCKER_NETWORK_CIDR

    Update the files before moving onto the next steps.
"

comment "Ex 2.2. Start up KinD clusters."
execute 'kind create cluster \
    --name cluster-1 \
    --config ./kind-config/cluster-1-v1.26.yaml;
kind create cluster \
    --name cluster-2 \
    --config ./kind-config/cluster-2-v1.26.yaml;
kind create cluster \
    --name cluster-3 \
    --config ./kind-config/cluster-3-v1.26.yaml;'

comment "Ex 2.3. Export kubeconfig for each cluster."
execute 'kind export kubeconfig \
        --name cluster-1 \
        --kubeconfig /tmp/kubecon-mco-demo/cluster-1-kubeconfig.yaml \
        --internal;
kind export kubeconfig \
        --name cluster-2 \
        --kubeconfig /tmp/kubecon-mco-demo/cluster-2-kubeconfig.yaml \
        --internal;
kind export kubeconfig \
        --name cluster-3 \
        --kubeconfig /tmp/kubecon-mco-demo/cluster-3-kubeconfig.yaml \
        --internal;'

comment_g "Ex 3. Set up MetalLB (needed for KinD setup)."
comment "Ex 3.1. Install MetalLB."
execute "kubectl apply --context kind-cluster-1 -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml;
kubectl apply --context kind-cluster-2 -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml;
kubectl apply --context kind-cluster-3 -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml"
comment "Ex 3.2. Ensure MetalLB is fully running before applying the MetalLB configurations."
execute "kubectl rollout --context kind-cluster-1 status deployment/controller -n metallb-system;
kubectl rollout --context kind-cluster-2 status deployment/controller -n metallb-system;
kubectl rollout --context kind-cluster-3 status deployment/controller -n metallb-system"
comment "Ex 3.3. Get MetalLB configs specific for the demo."
execute 'tar -xz -f kubecon-eu-2023.tar.gz \
    --strip=2 kubecon-eu-2023-main/tools/metallb/usage'

comment_r "NOTE:"
comment_w "Based on your Docker network setup, you will need to update the following files:
    - /tmp/kubecon-mco-demo/metallb/usage/metallb-cluster-1.yaml
    - /tmp/kubecon-mco-demo/metallb/usage/metallb-cluster-2.yaml
    - /tmp/kubecon-mco-demo/metallb/usage/metallb-cluster-3.yaml

    In each file, ensure that kubeadmConfigPatches -> apiServer -> certSANs matches with the following CIDR:

    $DOCKER_NETWORK_CIDR

    Update the files before moving onto the next steps.
"

comment "Ex 3.4. Configure MetalLB."
execute "kubectl apply --context kind-cluster-1 -f ./metallb/usage/metallb-cluster-1.yaml;
kubectl apply --context kind-cluster-2 -f ./metallb/usage/metallb-cluster-2.yaml;
kubectl apply --context kind-cluster-3 -f ./metallb/usage/metallb-cluster-3.yaml"

comment_g "Ex 4. Ensure Kubernetes API servers are accessible across clusters."
execute "kubectl patch svc kubernetes \\
    --context kind-cluster-1 \\
    -p '{\"spec\": {\"type\": \"LoadBalancer\"}}';
kubectl patch svc kubernetes \\
    --context kind-cluster-2 \\
    -p '{\"spec\": {\"type\": \"LoadBalancer\"}}';
kubectl patch svc kubernetes \\
    --context kind-cluster-3 \\
    -p '{\"spec\": {\"type\": \"LoadBalancer\"}}';"


comment_w "Now, the KinD configurations have been completed 🎉

From here, we will use these clusters for the multi-cluster setup."

comment_g "1. Create temporary directory."
# execute "mkdir /tmp/kubecon-mco-demo; cd /tmp/kubecon-mco-demo"
comment_w "Skipping this step, as it is covered from the extra step above."
execute "ls -lF"
comment "1.1. Copy the demo repository."
comment_w "Skipping this step, as it is covered from the extra step above."
# execute 'curl -sSL https://codeload.github.com/rytswd/kubecon-eu-2023/tar.gz/main \
#     -o kubecon-eu-2023.tar.gz'

comment_g "2. CA Certificates"
comment "2.1. Copy CA Certificate generation scripts from Istio."
execute "curl -sSL https://codeload.github.com/istio/istio/tar.gz/1.17.2 |
    tar -xz --strip=2 istio-1.17.2/tools/certs;
pushd certs > /dev/null"

comment "2.2. Create Root CA Certificate."
execute "make -f ./Makefile.selfsigned.mk root-ca"

comment "2.3. Create Intermediate CA Certificates for each cluster."
execute "make -f ./Makefile.selfsigned.mk cluster-1-cacerts;
make -f ./Makefile.selfsigned.mk cluster-2-cacerts;
make -f ./Makefile.selfsigned.mk cluster-3-cacerts;
popd > /dev/null"

comment "2.4. Create istio-system namespace in each cluster."
execute "kubectl create namespace --context kind-cluster-1 istio-system;
kubectl create namespace --context kind-cluster-2 istio-system;
kubectl create namespace --context kind-cluster-3 istio-system"

# shellcheck disable=SC2016
comment '2.5. Create `cacerts` secret in each cluster.'
execute 'kubectl create secret --context kind-cluster-1 \
    generic cacerts -n istio-system \
    --from-file=./certs/cluster-1/ca-cert.pem \
    --from-file=./certs/cluster-1/ca-key.pem \
    --from-file=./certs/cluster-1/root-cert.pem \
    --from-file=./certs/cluster-1/cert-chain.pem;
kubectl create secret --context kind-cluster-2 \
    generic cacerts -n istio-system \
    --from-file=./certs/cluster-2/ca-cert.pem \
    --from-file=./certs/cluster-2/ca-key.pem \
    --from-file=./certs/cluster-2/root-cert.pem \
    --from-file=./certs/cluster-2/cert-chain.pem;
kubectl create secret --context kind-cluster-3 \
    generic cacerts -n istio-system \
    --from-file=./certs/cluster-3/ca-cert.pem \
    --from-file=./certs/cluster-3/ca-key.pem \
    --from-file=./certs/cluster-3/root-cert.pem \
    --from-file=./certs/cluster-3/cert-chain.pem'

comment_g "3. Install Istio."
comment "3.1. Copy Istio installation manifests."
execute 'tar -xz -f kubecon-eu-2023.tar.gz \
    --strip=2 kubecon-eu-2023-main/manifests/istio/installation'

comment "3.2. Label istio-system namespace with the network topology."
execute 'kubectl label namespace \
    --context=kind-cluster-1 \
    istio-system topology.istio.io/network=cluster-1-network;
kubectl label namespace \
    --context=kind-cluster-2 \
    istio-system topology.istio.io/network=cluster-2-network;
kubectl label namespace \
    --context=kind-cluster-3 \
    istio-system topology.istio.io/network=cluster-3-network'

comment "3.3. Install istiod in each cluster."
execute "kubectl apply --context kind-cluster-1 -f ./istio/installation/istiod-manifests-cluster-1.yaml;
kubectl apply --context kind-cluster-2 -f ./istio/installation/istiod-manifests-cluster-2.yaml;
kubectl apply --context kind-cluster-3 -f ./istio/installation/istiod-manifests-cluster-3.yaml"

comment "3.4. Re-apply istiod installation spec."
execute "kubectl apply --context kind-cluster-1 -f ./istio/installation/istiod-manifests-cluster-1.yaml;
kubectl apply --context kind-cluster-2 -f ./istio/installation/istiod-manifests-cluster-2.yaml;
kubectl apply --context kind-cluster-3 -f ./istio/installation/istiod-manifests-cluster-3.yaml"

comment "3.5. Install Istio Gateway in each cluster."
execute "kubectl apply --context kind-cluster-1 -f ./istio/installation/istio-gateway-manifests-cluster-1.yaml;
kubectl apply --context kind-cluster-2 -f ./istio/installation/istio-gateway-manifests-cluster-2.yaml;
kubectl apply --context kind-cluster-3 -f ./istio/installation/istio-gateway-manifests-cluster-3.yaml"

comment_g "4. Establish Multi-Cluster Connections."
comment "4.1. Copy Gateway resource, which will be applied to all the clusters."
execute 'tar -xz -f kubecon-eu-2023.tar.gz \
    --strip=2 kubecon-eu-2023-main/manifests/istio/usage/cross-network-gateway.yaml'
comment "4.2. Apply Gateway resource to all the clusters."
execute "kubectl apply --context kind-cluster-1 -f ./istio/usage/cross-network-gateway.yaml;
kubectl apply --context kind-cluster-2 -f ./istio/usage/cross-network-gateway.yaml;
kubectl apply --context kind-cluster-3 -f ./istio/usage/cross-network-gateway.yaml"
comment "4.3. Create remote secrets for each cluster to connect to other clusters."
comment "4.3.1 For cluster-1 -> cluster-2"
execute '
CONTEXT=kind-cluster-1
CLUSTER=cluster-2

kubectl --context $CONTEXT --namespace istio-system create secret generic istio-remote-secret-$CLUSTER --from-file=$CLUSTER=${CLUSTER}-kubeconfig.yaml
kubectl --context $CONTEXT --namespace istio-system annotate secret istio-remote-secret-$CLUSTER networking.istio.io/cluster=$CLUSTER
kubectl --context $CONTEXT --namespace istio-system label secret istio-remote-secret-$CLUSTER istio/multiCluster=true
'
comment "4.3.2 For cluster-2 -> cluster-1"
execute '
CONTEXT=kind-cluster-2
CLUSTER=cluster-1

kubectl --context $CONTEXT --namespace istio-system create secret generic istio-remote-secret-$CLUSTER --from-file=$CLUSTER=${CLUSTER}-kubeconfig.yaml
kubectl --context $CONTEXT --namespace istio-system annotate secret istio-remote-secret-$CLUSTER networking.istio.io/cluster=$CLUSTER
kubectl --context $CONTEXT --namespace istio-system label secret istio-remote-secret-$CLUSTER istio/multiCluster=true
'
comment "4.3.3 For cluster-1 -> cluster-3"
execute '
CONTEXT=kind-cluster-1
CLUSTER=cluster-3

kubectl --context $CONTEXT --namespace istio-system create secret generic istio-remote-secret-$CLUSTER --from-file=$CLUSTER=${CLUSTER}-kubeconfig.yaml
kubectl --context $CONTEXT --namespace istio-system annotate secret istio-remote-secret-$CLUSTER networking.istio.io/cluster=$CLUSTER
kubectl --context $CONTEXT --namespace istio-system label secret istio-remote-secret-$CLUSTER istio/multiCluster=true
'
comment "4.3.4 For cluster-2 -> cluster-3"
execute '
CONTEXT=kind-cluster-2
CLUSTER=cluster-3

kubectl --context $CONTEXT --namespace istio-system create secret generic istio-remote-secret-$CLUSTER --from-file=$CLUSTER=${CLUSTER}-kubeconfig.yaml
kubectl --context $CONTEXT --namespace istio-system annotate secret istio-remote-secret-$CLUSTER networking.istio.io/cluster=$CLUSTER
kubectl --context $CONTEXT --namespace istio-system label secret istio-remote-secret-$CLUSTER istio/multiCluster=true
'

comment_g "5. Install Multi-Cluster Prometheus Setup."
comment "5.1. Create monitoring namespace."
execute "kubectl create namespace --context kind-cluster-1 monitoring;
kubectl create namespace --context kind-cluster-2 monitoring;
kubectl create namespace --context kind-cluster-3 monitoring"
comment "5.2. Label monitoring namespace for Istio sidecar."
execute 'kubectl label --context kind-cluster-1 \
    namespace monitoring istio-injection=enabled;
kubectl label --context kind-cluster-2 \
    namespace monitoring istio-injection=enabled;
kubectl label --context kind-cluster-3 \
    namespace monitoring istio-injection=enabled'
comment "5.3. Copy all Prometheus related definitions."
execute 'tar -xz -f kubecon-eu-2023.tar.gz \
    --strip=2 kubecon-eu-2023-main/manifests/prometheus'
comment "5.4. Install Prometheus Operator in each cluster."
execute "kustomize build prometheus/operator-installation | kubectl apply --context kind-cluster-1 --server-side -f -;
kustomize build prometheus/operator-installation | kubectl apply --context kind-cluster-2 --server-side -f -;
kustomize build prometheus/operator-installation | kubectl apply --context kind-cluster-3 --server-side -f -"
comment "5.5. Deploy Prometheus for collecting Istio metrics."
comment "5.5.1. Deploy Prometheus for Istio metrics collection."
execute "kustomize build prometheus/istio-collector | kubectl apply --context kind-cluster-1 -f -;
kustomize build prometheus/istio-collector | kubectl apply --context kind-cluster-2 -f -;
kustomize build prometheus/istio-collector | kubectl apply --context kind-cluster-3 -f -"
comment "5.5.2. Deploy Prometheus for federation."
execute "kustomize build prometheus/istio-federation-cluster-1 | kubectl apply --context kind-cluster-1 -f -;
kustomize build prometheus/istio-federation-cluster-2 | kubectl apply --context kind-cluster-2 -f -;
kustomize build prometheus/istio-federation-cluster-3 | kubectl apply --context kind-cluster-3 -f -"

comment "6. Install Thanos."
comment "6.1. Install Thanos to cluster-3."
execute 'helm install --repo https://charts.bitnami.com/bitnami \
    --kube-context kind-cluster-3 \
    --set receive.enabled=true \
    thanos thanos -n monitoring'

comment_w "Now, you have all the setup in place 🎉

You can now check cluster-3, which acts as the central observability cluster using Thanos.

Thanos Query Frontend exposes 10902 port by default, and you can use the following command to test:

{
    kubectl port-forward --context kind-cluster-3 \
        svc/thanos-query-frontend \
        10902:10902 -n monitoring
}

Then, you can access the Thanos Query Frontend UI at http://localhost:10902."

comment_w "Once you are done, you can run the following command to delete all the clusters created by this script.

{
    kind delete cluster --name cluster-1
    kind delete cluster --name cluster-2
    kind delete cluster --name cluster-3
}

Also, you can delete all the files used by this script by running the following command:

{
    rm -rf /tmp/kubecon-eu-2023
}
"
