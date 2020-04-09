# Setup GitOps in Kubernetes Cluster via Terraform

## What we want to do

Imagine you have a terraform config creating you your k8s cluster on one of the major cloud providers (I'm using Azure in this example). 

And now 

- you want to inital apply some config to your cluster. Some Namespaces, RABC-Config, ...

- you don't want to manually apply these ressources every time you change them

- you don't want everybody creating k8s ressources have a kubeconfig allowing him/her to do so

- instead every config yhould be in git (IaC)

- instead every config change should be approved by several people

- ...

-> use [GitOps Principle](https://www.weave.works/blog/what-is-gitops-really)

this Repository is a fairly easy try to implement GitOps for main k8s configuration

We are doing the following: 

1. Step: (optional) create a KinD Cluster to test this

2. Step: Setup your K8s config in a Git-Repository

3. Step: Setup Terraform to initally configure your cluster

4. Step: Setup GitOps via [Flux](https://github.com/fluxcd/flux)

5. Step: Test all

## Prerequisites

There is an (empty) K8s Cluster you can use.

If no you can create a test cluster via the "Kubernetes in Docker" project. I provided an example in the folder "kind"
-> 1. Step


## Create a Git-Repository containing your cluster config

I created a second GitHub [Repo here](https://github.com/nniikkoollaaii/GitOps_K8s_Cluster_via_Terraform_Config)

It contains not more than a readme and a kubernetes manifest creating a namespace called "test"

Setup your git-Repository and note your Clone-URL (ending .git)

## Setup terraform kubernetes provider

The Terraform Kubernetes provider can access k8s clusters via various ways.
An easy way is using a kubeconfig file. I use this in thes example to access my created KinD Cluster.

Alternativly you can use for example a Terraform Azure Data Source for Kubernetes Cluster to "import" an exisiting K8s Cluster in your Terraform config.

[Docs](https://www.terraform.io/docs/providers/azurerm/d/kubernetes_cluster.html)

    data "azurerm_kubernetes_cluster" "example" {
        name                = "myakscluster"
        resource_group_name = "my-example-resource-group"
        kube_admin_config {
            ...
        }
    }


If your creating your k8s cluster via terraform you shouldn't configure this cluster via terraform in the same "terraform apply" as [described here](https://www.terraform.io/docs/providers/kubernetes/index.html#stacking-with-managed-kubernetes-cluster-resources)

You should configure your K8s Cluster in a different "terraform apply" -> use here the above described Data Source


Export the kubeconfig file for your created KinD Cluster via

    kind export kubeconfig --name gitops --kubeconfig ./terraform/kind-kubeconfig

-> 3. Step

## Create Terraform ressources in K8s Cluster

see readme.md in Folder "terraform"
-> 4. Step

## Test your GitOps

    kubectl get ns

should show the namespace "gitops" with your resources
and the namespace "test" created by Flux

-> 5. Step

create a new file similar to the exisiting file in your k8s config repo to create one more namespace. Name it "foobar". Commit and push it.

Flux will scan the repository and apply changes every 5m (Default setting git.pollInterval)

    kubectl get ns

should show now the namespace "foobar" too.

## Comparision between CIOps and GitOps

- ToDo

## Helm Operator


### Authentication to git


You can reference an k8s secret in your HelmRelease. Poorly [documented but available](https://github.com/fluxcd/helm-operator/pull/172)


## ToDo

- GarbageCollection?

- Multi-Tenancy: https://www.weave.works/blog/developing-apps-multitenant-clusters-with-gitops