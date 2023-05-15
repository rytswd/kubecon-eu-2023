# KubeCon Demo Steps

This document details all the steps for the demo setup.

## Prerequisites

In order to run through the demo steps, you will need the following tools:

- Docker
- kubectl
- kind
- kustomize
- helm

Also, please note that having 3 KinD clusters will require some significant compute resource on your machine.

## About Each Step

Before going into the actaul multi-cluster configurations, we will go through local cluster setup using KinD. You can skip all those "extra" steps if you wish to use a different cluster.

## Step 1. Create Temp Directory for Demo

All the resources we will use would be placed in a temporary directory.

```sh
{
    # Create a temp directory - some commands require files rather than piping
    # stdout, etc. This also makes it clear which file is being created / used.
    mkdir /tmp/kubecon-mco-demo/
    cd /tmp/kubecon-mco-demo/
}
```

Once you are in the temp directory `/tmp/kubecon-mco-demo/`, run the following command to retrieve all the files from this repository.

```sh
{
    # Use curl to get .tar.gz version of this repository. With this approach,
    # we can easily test in any environment, even without git.
    curl -sSL https://codeload.github.com/rytswd/kubecon-eu-2023/tar.gz/main \
        -o kubecon-eu-2023.tar.gz
}
```


## Step 2. (Extra) Create KinD Clusters

This demo utilises local KinD clusters. If you wish to use other clusters, simply skip this step.

For other steps, however, it assumes the use of `kind-cluster-1`, `kind-cluster-2`, and `kind-cluster-3` for the names.

### Step 2.1. Pull Out Cluster Configurations

```sh
{
    # KinD can take in some configurations for cluster setup. As we need to
    # set up KinD clusters to appear as if they are in different networks, we
    # need extra configurations for each cluster.
    # The first step is to pull out the relevant KinD related configs from
    # kubecon-eu-2023.tar.gz, using `--strip` argument to simplify the directory
    # structure.
    tar -xz -f kubecon-eu-2023.tar.gz \
        --strip=2 kubecon-eu-2023-main/tools/kind-config
}
```

### ⚠️ NOTE: About Docker Network

In this demo, we make use of [MetalLB](https://metallb.universe.tf/) for creating separate networks and using LoadBalancer Service. Depending on your Docker network setup, you will need to update the following files:

- /tmp/kubecon-mco-demo/kind-config/cluster-1-v1.26.yaml
- /tmp/kubecon-mco-demo/kind-config/cluster-2-v1.26.yaml
- /tmp/kubecon-mco-demo/kind-config/cluster-3-v1.26.yaml

In each file, ensure that kubeadmConfigPatches -> apiServer -> certSANs matches with the following CIDR:

```sh
docker network inspect kind | jq -r ".[].IPAM.Config[0].Subnet"
```

Update the files before moving onto the next steps.

### Step 2.2. Start Up KinD Clusters


```sh
{
    # Start up KinD clusters using the above configurations. When creating the
    # clusters, make sure to name them differently so that we can easily target
    # the right cluster later.
    kind create cluster \
        --name cluster-1 \
        --config ./kind-config/cluster-1-v1.26.yaml;
    kind create cluster \
        --name cluster-2 \
        --config ./kind-config/cluster-2-v1.26.yaml;
    kind create cluster \
        --name cluster-3 \
        --config ./kind-config/cluster-3-v1.26.yaml;
}
```

### Step 2.3. Export kubeconfig for Each Cluster

```sh
{
    # kubeconfig is simply added when creating KinD clusters. We can use that
    # to interact with the cluster, but in the multi-cluster setup with Istio,
    # we need to ensure Istio Control Plane can talk to other clusters' API
    # server. This can be handled with `istioctl`, but in the following steps,
    # we will use the kubeconfig directly to see what is actually needed.
    kind export kubeconfig \
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
        --internal;
}
```

## Step 3. (Extra) Set Up MetalLB

MetalLB can make it a more realistic cluster setup, and allow you to not need to consider too much about the Docker Network (except for the IP CIDR range mentioned above).

This step isn't required if you are to work out the network setup using NodePort within Docker Network, and also if you are not using KinD, skip this step.


### Step 3.1. Install MetalLB

```sh
{
    # MetalLB installation is very simple and straightforward. Here, we are
    # simply using the files as they are from the official installation spec.
    #
    # MetalLB provides some configuration in separate configs, and we will be
    # doing that later.
    kubectl apply --context kind-cluster-1 \
        -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
    kubectl apply --context kind-cluster-2 \
        -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
    kubectl apply --context kind-cluster-3 \
        -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
}
```

### Step 3.2. Ensure MetalLB Is Fully Running

```sh
{
    # Ensure MetalLB Pods are fully up and running. Because the configurations
    # for MetalLB will be handled by these Pods, we can run these commands to
    # check the Deployment status.
    #
    # This command will wait until all the Pods are healthy. When they are up,
    # this will simply exit.
    kubectl rollout --context kind-cluster-1 \
        status deployment/controller -n metallb-system
    kubectl rollout --context kind-cluster-2 \
        status deployment/controller -n metallb-system
    kubectl rollout --context kind-cluster-3 \
        status deployment/controller -n metallb-system
}
```

### Step 3.3. Pull Out MetalLB Configurations

```sh
{
    # Like KinD configurations, we can pull out the relevant MetalLB related
    # configs from kubecon-eu-2023.tar.gz, using `--strip` argument to simplify
    # the directory structure.
    tar -xz -f kubecon-eu-2023.tar.gz \
        --strip=2 kubecon-eu-2023-main/tools/metallb/usage
}
```

### ⚠️ NOTE: About Docker Network Again

Based on your Docker network setup, you will need to update the following files:

- /tmp/kubecon-mco-demo/metallb/usage/metallb-cluster-1.yaml
- /tmp/kubecon-mco-demo/metallb/usage/metallb-cluster-2.yaml
- /tmp/kubecon-mco-demo/metallb/usage/metallb-cluster-3.yaml

In each file, ensure that IPAddressPool spec.addresses matches with the following CIDR:

```sh
docker network inspect kind | jq -r ".[].IPAM.Config[0].Subnet"
```

Update the files before moving onto the next steps.

For this demo setup, the MetalLB CIDR ranges are purposely made small. If you plan to play with more LB backed services, adjust the CIDRs accordingly. However, as all the KinD clusters will need to talk to each other to establish multi-cluster connection using the LB IPs, make sure that CIDR is within the Docker Network CIDR.

### Step 3.4. Configure MetalLB

```sh
{
    # The files applied to each cluster is almost identical, but they have
    # different sets of IP ranges.
    kubectl apply --context kind-cluster-1 \
        -f ./metallb/usage/metallb-cluster-1.yaml
    kubectl apply --context kind-cluster-2 \
        -f ./metallb/usage/metallb-cluster-2.yaml
    kubectl apply --context kind-cluster-3 \
        -f ./metallb/usage/metallb-cluster-3.yaml
}
```

## Step 4. (Extra) Ensure Kubernetes API Servers Are Accessible

```sh
{
    # In each cluster, we are updating the `kubernetes.default.svc` Service to
    # use LoadBalancer instead of ClusterIP. As the MetalLB is configured in the
    # previous step, each cluster can have the Kubernetes API server exposed to
    # other clusters.
    kubectl patch svc kubernetes \
        --context kind-cluster-1 \
        -p '{"spec": {"type": "LoadBalancer"}}'
    kubectl patch svc kubernetes \
        --context kind-cluster-2 \
        -p '{"spec": {"type": "LoadBalancer"}}'
    kubectl patch svc kubernetes \
        --context kind-cluster-3 \
        -p '{"spec": {"type": "LoadBalancer"}}'
}
```

## Step 5. Prepare CA Certificates for mTLS

> **NOTE**: You should complete this step before installing Istio to clusters.

Multi-cluster communication needs mTLS (mutual TLS) to handle the inter-cluster communication securely. The idea is that, each cluster gets a set of TLS certificate, all signed by the same Root CA. The Root CA used to sign can be any self-signed certificate.

Istio comes with some default dummy certificate provided, but it is certainly not desirable for real use cases. In order to make it more realistic multi-cluster communication, the following steps will create a new certificate for each cluster, which is signed by a dedicated Root CA.

### Step 5.1. Copy CA Certificate Generation Scripts from Istio

```sh
{
    # Istio repository has a script to generate the certificates. This is a
    # rather simple script, and is meant to be used only for Istio use cases.
    # Similar to the above KinD setup, we are using curl to get .tar.gz format
    # of the repository, and only pull out the directory `tools/certs`.
    curl -sSL https://codeload.github.com/istio/istio/tar.gz/1.17.2 |
        tar -xz --strip=2 istio-1.17.2/tools/certs;
}
```

### Step 5.2. Create Root CA Certificate

```sh
{
    # Before generating all the certificates, we change directory to `certs`
    # directory. This is not strictly necessary, but makes the file management
    # simpler and cleaner. All the certificates will then be created under the
    # same `certs` directory.
    pushd certs > /dev/null

    # Before generating the certificate for each cluster, we need to create a
    # Root CA Certificate, which can be used to sign the actual certificates
    # in the next step.
    # As Istio's script is a Makefile, we are using make command. It means we
    # could pass `-f` flag and use different directory if you wish so.
    make -f ./Makefile.selfsigned.mk root-ca

    # Although we would be back to the same directory in the next step, making
    # sure that we get back to the original directory we were in before.
    popd > /dev/null
}
```

### Step 5.3. Create Intermediate CA Certificates for Each Cluster

```sh
{
    # Get back to the `certs` directory for generating the intermediate
    # certificates.
    pushd certs > /dev/null

    # Create Intermediate CA Certificates for each cluster. All clusters have
    # their own certs for security reason. These certs are signed by the above
    # Root CA.
    make -f ./Makefile.selfsigned.mk cluster-1-cacerts;
    make -f ./Makefile.selfsigned.mk cluster-2-cacerts;
    make -f ./Makefile.selfsigned.mk cluster-3-cacerts;

    # Once we have all the certificates created, get back to the original
    # directory.
    popd > /dev/null
}
```

### Step 5.4. Create `istio-system` Namespace in Each Cluster

```sh
{
    # In a simple Istio installation, we do not have to create the namespace
    # beforehand, as `istioctl` will do that for us. However, in case of the
    # multi-cluster installation, we would need to have the certificates used
    # in mTLS created before installing Istio.
    # As a side note, you could skip this step, and create the secrets after
    # installing Istio in each cluster. However, if you do that, you would need
    # to restart many components to ensure they pick up the right certificates
    # for inter-cluster communication.
    kubectl create namespace --context kind-cluster-1 istio-system
    kubectl create namespace --context kind-cluster-2 istio-system
    kubectl create namespace --context kind-cluster-3 istio-system
}
```

### Step 5.5 Create `cacerts` Secret in Each Cluster

```sh
{
    # Istio checks the secret `cacerts` upon initialisation. This secret
    # consists of the Root CA certificate, and the Intermediate CA
    # certificate. This is a step to ensure we can have mTLS across clusters,
    # but also they allow us to have Strict mTLS within the cluster using the
    # certificates in each cluster.
    kubectl create secret --context kind-cluster-1 \
        generic cacerts -n istio-system \
        --from-file=./certs/cluster-1/ca-cert.pem \
        --from-file=./certs/cluster-1/ca-key.pem \
        --from-file=./certs/cluster-1/root-cert.pem \
        --from-file=./certs/cluster-1/cert-chain.pem
    kubectl create secret --context kind-cluster-2 \
        generic cacerts -n istio-system \
        --from-file=./certs/cluster-2/ca-cert.pem \
        --from-file=./certs/cluster-2/ca-key.pem \
        --from-file=./certs/cluster-2/root-cert.pem \
        --from-file=./certs/cluster-2/cert-chain.pem
    kubectl create secret --context kind-cluster-3 \
        generic cacerts -n istio-system \
        --from-file=./certs/cluster-3/ca-cert.pem \
        --from-file=./certs/cluster-3/ca-key.pem \
        --from-file=./certs/cluster-3/root-cert.pem \
        --from-file=./certs/cluster-3/cert-chain.pem
}
```

## Step 6. Install Istio

After ensuring CA certificates are in place, we can now move onto installing Istio.

You could use the official `istioctl` CLI to install, but there are a few caveats with it.

- `istioctl` CLI itself has a specific version, and can only install Istio components to the cluster based on that given version
- `istioctl install` manages the resource installation order, and wait for prerequisites to be in place - all of which are pretty simple behind the scenes
- Using `istioctl` would mean that you are getting some imperative cluster management in place, and thus you will need to check the cluster resources to find what's actually running in the cluster

Because there are so many moving parts with Service Mesh in general, the steps and materials in this repo are focused to provide you the declarative definitions as much as I could.

So with that, let's move onto install Istio, using manifests.


### Step 6.1. Copy Istio Installation Manifests

```sh
{
    # Like KinD and MetalLB configurations, we can pull out the Istio
    # installation configs from kubecon-eu-2023.tar.gz, using `--strip` argument
    # to simplify the directory structure.
    tar -xz -f kubecon-eu-2023.tar.gz \
        --strip=2 kubecon-eu-2023-main/manifests/istio/installation
}
```

### Step 6.2. Label `istio-system` Namespace with Network Topology


```sh
{
    # Because we have created the `istio-system` namespace when creating the
    # certificates, we are simply labeling the namespaces in this step. This
    # label is important for Istio Control Plane to know which network they
    # belong to. In this case, we are labeling all the namespaces with
    # different network names, meaning we are installing Istio based on
    # multi-primary on different networks.
    kubectl label namespace \
        --context=kind-cluster-1 \
        istio-system topology.istio.io/network=cluster-1-network
    kubectl label namespace \
        --context=kind-cluster-2 \
        istio-system topology.istio.io/network=cluster-2-network
    kubectl label namespace \
        --context=kind-cluster-3 \
        istio-system topology.istio.io/network=cluster-3-network
}
```


### Step 6.3. Install Istio Control Plane

```sh
{
    # After the namespace is configured, we can finally move to install Istio
    # to each cluster.
    # The installation manifests are in a single file, which was generated by
    # `istioctl manifest generate` command. You can find more about it in
    # `/manifests/istio/README.md`. If you wish to upgrade Istio version, you
    # will need to install `istioctl` based on the version you need, and
    # generate manifest for each cluster. Just like `istioctl install`, we are
    # using some IstioOperator CR for generating manifests for each cluster.
    kubectl apply --context kind-cluster-1 \
        -f ./istio/installation/istiod-manifests-cluster-1.yaml
    kubectl apply --context kind-cluster-2 \
        -f ./istio/installation/istiod-manifests-cluster-2.yaml
    kubectl apply --context kind-cluster-3 \
        -f ./istio/installation/istiod-manifests-cluster-3.yaml
}
```


### Step 6.4. Re-apply Istio Control Plane Spec

```sh
{
    # Because Istio installation definitions are all put into a single file
    # when using `istioctl manifest generate`, they will contain CRD and also
    # the resources based on those CRDs. It means that some resources will be
    # reported to be missing when applying in the above step. It is simple
    # enough to re-apply the same exact specs to complete the installation, and
    # thus we are not using `istioctl`.
    kubectl apply --context kind-cluster-1 \
        -f ./istio/installation/istiod-manifests-cluster-1.yaml
    kubectl apply --context kind-cluster-2 \
        -f ./istio/installation/istiod-manifests-cluster-2.yaml
    kubectl apply --context kind-cluster-3 \
        -f ./istio/installation/istiod-manifests-cluster-3.yaml
}
```

### Step 6.5. Install Istio Gateway in Each Cluster

```sh
{
    # Istio Control Plane is only a part of the story for the multi-cluster
    # communication. We have to have an extra Istio Data Plane setup of
    # creating Istio IngressGateway, so that any traffic coming from other
    # clusters can be checked with mTLS.
    # Similar to the Control Plane installation, the installation spec is
    # created based on `istioctl manifest generate`. Istio IngressGateway
    # installation spec is pretty simple, and this does not require any
    # re-apply or anything.
    kubectl apply --context kind-cluster-1 \
        -f ./istio/installation/istio-gateway-manifests-cluster-1.yaml
    kubectl apply --context kind-cluster-2 \
        -f ./istio/installation/istio-gateway-manifests-cluster-2.yaml
    kubectl apply --context kind-cluster-3 \
        -f ./istio/installation/istio-gateway-manifests-cluster-3.yaml
}
```

## Step 7. Establish Multi-Cluster Connections

At this point, we have Istio Control Plane and Data Plane installed in all the clusters. However, each cluster is running on their own, and they don't know about other clusters.

In this step, we will look at each step of establishing the connection between clusters. With Istio's default multi-cluster setup, `cluster-1` will know how to connect to _all Services_ in `cluster-2`. If you need more fine-tuned connection handling, there are a few ways to do that. We will cover more about what it means to establish inter-cluster communication logic.

### Step 7.1. Pull Out Cross Network `Gateway` Configuration


```sh
{
    # Like KinD configurations, we can pull out the relevant Istio configuration
    # specifically for `Gateway` from kubecon-eu-2023.tar.gz, using `--strip`
    # argument to simplify the directory structure.

    # Istio's cross-network-gateway is a simple `Gateway` CR provided by the
    # Istio official repository (you can use a script to generate this).
    # With this resource, we can configure Istio IngressGateway (and other Data
    # Plane components).
    #
    # The configuration is quite simple:
    #
    # apiVersion: networking.istio.io/v1alpha3
    # kind: Gateway
    # metadata:
    #   name: cross-network-gateway
    #   namespace: istio-system
    # spec:
    #   selector:
    #     istio: eastwestgateway
    #   servers:
    #     - port:
    #         number: 15443
    #         name: tls
    #         protocol: TLS
    #       tls:
    #         mode: AUTO_PASSTHROUGH
    #       hosts:
    #         - "*.local"
    #
    # This simply ensures that Istio IngressGateway would receive incoming
    # traffic to 15443 port based on `*.local` address, and simply pass it to
    # the target service without terminating TLS (mode: AUTO_PASSTHROUGH).
    # Unlike mode: PASSTHROUGH, this assumes the use of mTLS, which is how
    # inter-cluster communication works.
    tar -xz -f kubecon-eu-2023.tar.gz \
        --strip=2 kubecon-eu-2023-main/manifests/istio/usage/cross-network-gateway.yaml
}
```

### Step 7.2. Apply `cross-network-gateway` Resuorce to Each Cluster

```sh
{
    # We are simply applying the same resource to each cluster. If we have
    # deployed the Istio IngressGateway based on different labels, we would need
    # to adjust the spec accordingly, but in this simple example, the only
    # difference between the Istio IngressGateways deployed in each cluster is
    # the network name only, and thus can use the same configuration for all.
    kubectl apply --context kind-cluster-1 \
        -f ./istio/usage/cross-network-gateway.yaml
    kubectl apply --context kind-cluster-2 \
        -f ./istio/usage/cross-network-gateway.yaml
    kubectl apply --context kind-cluster-3 \
        -f ./istio/usage/cross-network-gateway.yaml
}
```

### Step 7.3. Create Remote Secrets for Each Inter-Cluster Communication

This step ensures that Istio Control Plane can talk to other clusters to find what Services are running in other clusters. However, if you need a one way traffic (such as `cluster-1 -> cluster-3`, but not from `cluster-3` back to `cluster-1`), you could simply skip creating the remote secret in `cluster-3`.

The official way for creating remote secrets use `istioctl create-remote-secret`, and is probably the simplest approach. For KinD based testing, however, it is actually simpler to use the kubeconfig directly, which would allow us not to consider the Kubernetes API Server discovery. The kubeconfig used here comes from the Step 2.3, and if you are using non-KinD clusters, you may want to use `istioctl` instead.

```sh
{
    # This step is for cluster-1 -> cluster-2

    CONTEXT=kind-cluster-1
    CLUSTER=cluster-2

    # Firstly, create a secret based on kubeconfig for the target cluster (in
    # this case `cluster-2`). We make sure that the name of the secret matches
    # the convention used by istioctl.
    kubectl --context $CONTEXT \
        --namespace istio-system \
        create secret generic istio-remote-secret-$CLUSTER \
        --from-file=$CLUSTER=${CLUSTER}-kubeconfig.yaml

    # Next, we also annotate with the network topology, the same way as
    # istioctl.
    kubectl --context $CONTEXT \
        --namespace istio-system \
        annotate secret istio-remote-secret-$CLUSTER \
        networking.istio.io/cluster=$CLUSTER
    # And finally, we ensure that the secret is labeled for multi-cluster use
    # case.
    kubectl --context $CONTEXT \
        --namespace istio-system \
        label secret istio-remote-secret-$CLUSTER \
        istio/multiCluster=true
}
```

The rest of the steps are exactly the same as above, just for different cluster sets.


```sh
{
    # This step is for cluster-2 -> cluster-1

    CONTEXT=kind-cluster-2
    CLUSTER=cluster-1

    kubectl --context $CONTEXT \
        --namespace istio-system \
        create secret generic istio-remote-secret-$CLUSTER \
        --from-file=$CLUSTER=${CLUSTER}-kubeconfig.yaml
    kubectl --context $CONTEXT \
        --namespace istio-system \
        annotate secret istio-remote-secret-$CLUSTER \
        networking.istio.io/cluster=$CLUSTER
    kubectl --context $CONTEXT \
        --namespace istio-system \
        label secret istio-remote-secret-$CLUSTER \
        istio/multiCluster=true
}
```


```sh
{
    # This step is for cluster-1 -> cluster-3

    CONTEXT=kind-cluster-1
    CLUSTER=cluster-3

    kubectl --context $CONTEXT \
        --namespace istio-system \
        create secret generic istio-remote-secret-$CLUSTER \
        --from-file=$CLUSTER=${CLUSTER}-kubeconfig.yaml
    kubectl --context $CONTEXT \
        --namespace istio-system \
        annotate secret istio-remote-secret-$CLUSTER \
        networking.istio.io/cluster=$CLUSTER
    kubectl --context $CONTEXT \
        --namespace istio-system \
        label secret istio-remote-secret-$CLUSTER \
        istio/multiCluster=true
}
```



```sh
{
    # This step is for cluster-2 -> cluster-3

    CONTEXT=kind-cluster-2
    CLUSTER=cluster-3

    kubectl --context $CONTEXT \
        --namespace istio-system \
        create secret generic istio-remote-secret-$CLUSTER \
        --from-file=$CLUSTER=${CLUSTER}-kubeconfig.yaml
    kubectl --context $CONTEXT \
        --namespace istio-system \
        annotate secret istio-remote-secret-$CLUSTER \
        networking.istio.io/cluster=$CLUSTER
    kubectl --context $CONTEXT \
        --namespace istio-system \
        label secret istio-remote-secret-$CLUSTER \
        istio/multiCluster=true
}
```

Note how there is no remote secret setup for `cluster-3 -> cluster-1` and `cluster-3 -> cluster-2`. This is just an example of how you can do that.


## Step 8. Install Prometheus

There are several ways to install Prometheus, but when handling Service Mesh metrics, you can expect high cardinality which you need to manage based on your business requirements.

In order to simulate more realistic use cases, the steps here will make use of multiple Prometheus instance, backed by Prometheus Operator. It means we can set up more Prometheus relatively easily by adding more Prometheus CR, and also have Alertmanager deployed together. Prometheus has a lot of moving parts by itself, and managing them in a declarative fashion can make those configuration details easier to grasp.

### Step 8.1. Create `monitoring` Namespace

```sh
{
    # We will deploy the observability stack into this `monitoring` namespace.
    # This can be any namespace, but has to have Istio sidecar injected. In
    # order not to overlap with other processes, we will use a dedicated
    # namespace instead.
    kubectl create namespace --context kind-cluster-1 monitoring
    kubectl create namespace --context kind-cluster-2 monitoring
    kubectl create namespace --context kind-cluster-3 monitoring
}
```

### Step 8.2. Label `monitoring` Namespace for Istio Sidecar Injection

```sh
{
    # Label `monitoring` namespace with `istio-injection=enabled`. This approach
    # is somewhat an old approach, where you only needed one Istio Control
    # Plane in the cluster. In the real production scenarios, we would want to
    # have canary deployment for Istio Control Plane, meaning we should instead
    # use `istio.io/rev` label to specify the revision to be used.
    kubectl label --context kind-cluster-1 \
        namespace monitoring istio-injection=enabled
    kubectl label --context kind-cluster-2 \
        namespace monitoring istio-injection=enabled
    kubectl label --context kind-cluster-3 \
        namespace monitoring istio-injection=enabled
}
```

### Step 8.3. Pull Out Prometheus Related Configurations

```sh
{
    # Like KinD configurations, we can pull out the relevant Prometheus related
    # configurations around Prometheus Operator, Prometheus instances, etc. from
    # kubecon-eu-2023.tar.gz, using `--strip` argument to simplify the directory
    # structure.
    tar -xz -f kubecon-eu-2023.tar.gz \
        --strip=2 kubecon-eu-2023-main/manifests/prometheus
}
```

### Step 8.4. Install Prometheus Operator in Each Cluster

```sh
{
    # Prometheus Operator is simple enough to install using the official
    # installation spec, similar to MetalLB. However, it uses the `default`
    # namespace by default. It is not a problem per se, but if we want to update
    # it to other namespace, ClusterRoleBinding needs to be adjusted based on
    # the installation path. In order to make the installation simple enough,
    # we are using the official installation with kustomize to target the
    # `monitoring` namespace.
    # Also, because the Prometheus Operator CRDs are quite lengthy and exceeds
    # the limit for client side apply, we are using `--server-side` flag to have
    # them applied on the server instead.
    kustomize build prometheus/operator-installation |
        kubectl apply --context kind-cluster-1 --server-side -f -
    kustomize build prometheus/operator-installation |
        kubectl apply --context kind-cluster-2 --server-side -f -
    kustomize build prometheus/operator-installation |
        kubectl apply --context kind-cluster-3 --server-side -f -
}
```

### Step 8.5. Deploy Prometheus for Istio Metrics

We will be deploying two separate Prometheus instances.

The first Prometheus is "istio-collector", which collects all metrics from Istio sidecars and endpoints. This means it would have the live data, and is best for realtime monitoring and alerting. However, it also means the data cardinality is quite high, and will be rather noisy for complicated scenarios.

The second Prometheus is "istio-federation", which bundles all Prometheus metrics retrieved by "istio-collector", and aggregate them for better monitoring experiences.

> Prometheus for Istio Collector

```sh
{
    # We are using another Kusotmize setup, as there are multiple files
    # associated with this installation. You can find the following directories
    # in the Kustomize setup.
    #
    # - installation: This is the Prometheus CR, which will be read by
    #   Prometheus Operator. Because of the namespace difference, the Kustomize
    #   patch is necessary. The installation spec actually has a few moving
    #   parts to ensure it can talk to Istio Sidecar __without__ strict mTLS.
    #   You can find more details in the installation spec.
    #
    # - istio-configs: In order to ensure Istio doesn't get in the way for
    #   Prometheus to scrape metrics, there are a few adjustments made in the
    #   Istio configurations.
    #
    # - prometheus-configs: This is the set of actual Prometheus scraping
    #   definitions. They are about pulling out metrics from all Istio related
    #   components, but also ensuring that the data retrieved could be used for
    #   federation later on, by adding a prefix such as "federate:". we would
    #   see how Prometheus "istio-federation" setup takes advantage of this
    #   setup for better metrics management.
    kustomize build prometheus/istio-collector |
        kubectl apply --context kind-cluster-1 -f -
    kustomize build prometheus/istio-collector |
        kubectl apply --context kind-cluster-2 -f -
    kustomize build prometheus/istio-collector |
        kubectl apply --context kind-cluster-3 -f -
}
```

> Prometheus for Istio Federation

```sh
{
    # For "istio-federation" setup, the configurations are slightly simpler.
    # Because Prometheus uses Istio Sidecar __only to retrieve certificates__,
    # and Prometheus Federation is about connecting multiple Prometheus
    # instances, we do not require Istio configurations to be added for this.
    #
    # The installation spec is quite similar to "istio-collector", which uses
    # Istio Sidecar only for certificate handling. The notable difference is
    # that "istio-federation" has a Remote Write endpoint for data retention.
    # This is a simple approach to merge all the metrics taken into a dedicated
    # central observability cluster, in our case `cluster-3`.
    #
    # Prometheus scraping config for this is quite simple. It finds the metrics
    # with "federate:" prefix, and strips the prefix.
    kustomize build prometheus/istio-federation-cluster-1 |
        kubectl apply --context kind-cluster-1 -f -
    kustomize build prometheus/istio-federation-cluster-2 |
        kubectl apply --context kind-cluster-2 -f -
    kustomize build prometheus/istio-federation-cluster-3 |
        kubectl apply --context kind-cluster-3 -f -
}
```

**References**:

[Istio Official Observability Best Practices](https://istio.io/latest/docs/ops/best-practices/observability/#federation-using-workload-level-aggregated-metrics)
[Blog post "Federated Prometheus to reduce Metric Cardinality" by Karl Stoney from AutoTrader](https://karlstoney.com/2020/02/25/federated-prometheus-to-reduce-metric-cardinality/)

**NOTE**: You can also find some more detailed references mentioned in the configuration files.


## Step 9. Install Thanos

The last step is to ensure we have some data retention, deduplication, performant query setup with Thanos.

Thanos is the choice here, because it is one of the simpler solutions to handle long term retention of Prometheus metrics. Thanos's standard deployment uses a sidecar approach, where Prometheus is not aware of Thanos at all, and Thanos simply retrieves the metrics and send it down to an object store every now and then.

While this approach is simple to handle, if Prometheus Pod gets restarted for any reason, you may lose up to 2 hour worth of metrics due to the timing of Thanos to save the metrics into the object store. Cortex and Grafan Mimir are other alternatives, and they work as "Remote Write endpoint" for data retention. Thanos has the same capability by using "Thanos Receive(r)" service, and we will be using that for this demo.

Also, with this approach, Thanos is only needed in the "target" cluster where the metrics are saved in.

### Step 9.1. Install Thanos to `cluster-3`

```sh
{
    # Notice how we are only deploying Thanos into `cluster-3`. Thanks to all
    # the multi-cluster configurations in place, Prometheus in each cluster can
    # simply talk to Thanos in `cluster-3` as if the Thanos endpoint is
    # available within the cluster.
    #
    # This "Thanos Receiver" approach is one of many deployment patterns, but
    # it is chosen for the simplicity, and also how it can be replaced with
    # Cortex, Grafana Mimir, etc.
    #
    # As there could be network errors and many other potential problems with
    # sending metrics over to a remote cluster (from the `cluster-1` and
    # `cluster-2` point of view). Because of that, while the metrics in a
    # central location is easier to manage, we would need to be extra careful
    # how to manage the data within each cluster, and alert when any issues
    # found.
    helm install --repo https://charts.bitnami.com/bitnami \
        --kube-context kind-cluster-3 \
        --set receive.enabled=true \
        thanos thanos -n monitoring
}
```


## Step 10. Play and Explore 🎢

With all the steps above, we finally have the 3 KinD clusters connected with Istio to provide full multi-cluster experince, while ensuring the metrics are consolidated into Thanos in `cluster-3`.

Try deploying more resources in each cluster, send traffic from one to the other, and see how you would see Service Mesh can retrieve all the metrics.

In order to understand the metrics use cases and data sources, you can check out `thanos-query-frontend`, a very powerful query solution for all the metrics.

## Clean Up

After you are done, you can simply delete all the clusters.

```sh
{
    kind delete cluster --name cluster-1
    kind delete cluster --name cluster-2
    kind delete cluster --name cluster-3
}
```

Also, you can delete the temporary directory where we copied all the configurations into.

```sh
rm -rf /tmp/kubecon-mco-demo
```
