#!/usr/bin/env bash
# shellcheck disable=SC2016

# shellcheck disable=SC2034
demo_helper_type_speed=5000

# shellcheck source=./demo-helper.sh
. "$(dirname "$0")/demo-helper.sh"

comment_g "1. Create temporary directory."
execute "mkdir /tmp/kubecon-mco-demo; cd /tmp/kubecon-mco-demo"
execute "ls -lF"
comment "1.1. Copy the demo repository."
execute 'curl -sSL https://codeload.github.com/rytswd/kubecon-eu-2023/tar.gz/main \
    -o kubecon-eu-2023.tar.gz'

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
