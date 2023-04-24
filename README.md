# KubeCon + CloudNativeCon Europe 2023 

![slide](/docs/assets/slide-title.png)

> Date: 19th April, 2023
>
> Title: **Multi-Cluster Observability with Service Mesh - That Is a Lot of Moving Parts!?**
>
> Presented by [@rytswd](https://github.com/rytswd)

Official Website: https://sched.co/1Hyd7

Original Recording: _To be updated_

Original Slide: https://dub.sh/kubecon-eu-2023-mco

Follow-up Video: _To be added_

## 🌄 About This Repository

This repository holds the supplementary materials for my talk at KubeCon.

- Demo Steps and Details
- References

### About Demo

The demo during the talk was fully based on the input in this repository. You should be able to replicate the same setup following the steps detailed in this repository.

Also, before this talk goes available on YouTube, I will be also working to create some more example setup for using other tools.

### About Demo Script

During the presentation, I cheated 🫣 a little by using a script to mock the typing effect. This is backed by a simple shell script https://github.com/rytswd/cli-demo-helper.

### Why X? Why Not Y?

I designed my talk specifically on "moving parts" around multi-cluster observability. The solutions such as `istioctl` provide friendly UX for Istio management, but from my own experience, it is crucial to understand those "moving parts" in order to handle even more complex scenarios.

The demo was meant to be something anyone can replicate in their own environment. Once you follow the demo details, you should be able to see where the actual "moving parts" are, and how to tackle them for your use cases.


## 🌅 Contents

### Prerequisites

In order to run through the demo steps, you will need the following tools:

- Docker
- kubectl
- kind
- kustomize
- helm

Also, please note that having 3 KinD clusters will require some significant compute resource on your machine.

### Simplest, All In One

``` sh
bash <(curl -sSL 'https://raw.githubusercontent.com/rytswd/kubecon-eu-2023/main/demo-all.sh')
```

The above script will give you the typing effect I used in my demo, and will set up the same exact setup.

### Detailed Steps

Please check out [Demo Steps](demo-steps.md) for details.

### Clean Up

To be updated

### Troubleshooting

To be updated


## 🔎 References

To be updated
