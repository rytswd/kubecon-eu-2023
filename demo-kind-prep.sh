#!/usr/bin/env bash

# shellcheck disable=SC2034
demo_helper_type_speed=5000

# shellcheck source=./demo-helper.sh
. "$(dirname "$0")/demo-helper.sh"

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
    - ./kind-config/cluster-1-v1.26.yaml
    - ./kind-config/cluster-2-v1.26.yaml
    - ./kind-config/cluster-3-v1.26.yaml

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
    - ./metallb/usage/metallb-cluster-1.yaml
    - ./metallb/usage/metallb-cluster-2.yaml
    - ./metallb/usage/metallb-cluster-3.yaml

    In each file, ensure that IPAddressPool spec.addresses matches with the following CIDR:

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
