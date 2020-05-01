# Setup GitOps in Kubernetes Cluster via Terraform

## What we want to do

Imagine you have a terraform config creating you your k8s cluster on one of the major cloud providers (I'm using Azure in this example). 

And now 

- you want to inital apply some config to your cluster. Some Namespaces, RABC-Config, ...

- you don't want to manually apply these ressources every time you change them

- you don't want everybody creating k8s ressources have a kubeconfig allowing him/her to do so

- instead every config should be in git (IaC)

- instead every config change should be approved by several people

- ...

-> use [GitOps Principle](https://www.weave.works/blog/what-is-gitops-really)

- with this approach your CI/CD System don't have to contain credentials to access your kubernetes cluster (Pull-based approach)

- the complete definition of your cluster's state is in git and accessible to you in case of an recreation of your k8s cluster


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

## GitOps Architecture

With Terraform you're setting up your admin flux and helm operator instance
Flux is for syncing plain kubernetes manifests to your cluster
The Helm Operator watches for Custom Resource Definitions "HelmRelease" and applies a Helm Release of a Helm Chart to your cluster

### Admin Repo

The admin flux instance points to your admin cluster config [git repository](https://github.com/nniikkoollaaii/GitOps_K8s_Cluster_via_Terraform_Config)
Here you're defining your namespaces, RBAC definitions, ...
And you're setting up flux and helm operator instances for your teams with restricting rbac roles

All your teams could use your admin git repo and therefore the admin flux and helm operator instances. But then you can't prohibit the creation of ressources in namespaces a team is not allowed to do. At least not with RBAC. You can manually review their pull requests and so on but therefor RBAC is made.

### Team1

So you have Team1 which uses a single namespace for their app.
In the admin repo you're defining their namespace and a HelmRelease for Flux and one for HelmOperator so that the Admin HelmOperator picks these HelmReleases off and deploys a HelmRelease in the team's namespace. In the HelmRelease values are defined for the Helm Chart, so that Flux and HelmOperator are created with RBAC with permissions only for the teams namespace.

Team1's flux is pointing to their [Deployment Git Repo](https://github.com/nniikkoollaaii/GitOps_K8s_Cluster_via_Terraform_Config_Team1) at subpath "manifests".
Here team1 can define k8s ressources like additional roles, ... and HelmReleases. 
Team1-Flux syncs these HelmReleases in Namespace team1. Here Team1-HelmOperator picks it off and depoys these application helm chart which is defined ad the same Git Repo at subpath "helm/"

### Team2

Team2 has a more complex application and needs a staging environment for the application

So in the admin repo multiple namespaces defined:
team2-mgmt: contains Team2-Flux with RBAC permissions for namespaces of team2
team2-dev: contains a Helm-Operator instance with RBAC for namespace team2-dev
team2-prod: contains a Helm-Operator instance with RBAC for namespace team2-prod

Team2-Flux points to a [overall config repo](https://github.com/nniikkoollaaii/GitOps_K8s_Cluster_via_Terraform_Config_Team2_Manifests) for team2 deployment.
In this example it defines the HelmRelease manifest for deploying a Helm release to both staging environments.

Both HelmRelease are pointing to a Helm Chart in Team2's [Helm Chart Git Repository](https://github.com/nniikkoollaaii/GitOps_K8s_Cluster_via_Terraform_Config_Team2_Helm) for their application.
The HelmRelease for the dev stage at the develop branch and the HelmRelease for the prod stage at the master branch.
So you can promote changes in your helm chart and new image versions used in your helm chart via a branch merge

Image versions of your app could be hold in a values file right next to your chart and be referenced by your HelmRelease object.
This is similar to create an helm release via "helm install test ./example -f values.prod.yaml"

### Helm Operator

#### Authentication to git


You can reference an k8s secret in your HelmRelease to access your git repository. Poorly [documented but available](https://github.com/fluxcd/helm-operator/pull/172)


## Securly save secrets in git

Using the [sealed secret controller](https://github.com/bitnami-labs/sealed-secrets) from bitnami you can save encrypted secret values in your public git repo. An controller in your kubernetes cluster will detect CRDs of type SealedSecrets and decode them in normal K8s Secrets to use with your pod manifest.

The Helm Chart is included in this repo at /helm/sealed-secrets.

An HelmRelease is in the Admin-Config Repo.

### get binary

download from [here](https://github.com/bitnami-labs/sealed-secrets/releases)

### Disaster Recovery

When sealed secret controller's private key secret is lost you cannot decrypt your secrets. You should backup it to still be able to decrypt your secrets saved in git in event of an disaster

    kubectl get secret -n adm -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > sealed-secrets.key

In event of a disaster recovery replace the automatically created new key with your backup

    kubectl apply -f sealed-secrets.key
    kubectl delete pod -n adm -l name=sealed-secrets-controller

### encrypt secrets

get the public cert

    kubeseal --fetch-cert --controller-namespace=adm --controller-name=sealed-secrets > sealed-secrets.cert.pem

create secret with username and password to access your git repo

    kubectl -n team1 create secret generic git-auth --from-literal=username=<username to access git> --from-literal=password=<password> --dry-run -o json > git.team1.secret.json

adn seal it

    kubeseal --format=yaml --cert=sealed-secrets.cert.pem <git.team1.secret.json > git.team1.sealedsecret.yaml


delete the json file and copy the file git.team1.secret.yaml to /team1 in your [Admin-Config-Repo](https://github.com/nniikkoollaaii/GitOps_K8s_Cluster_via_Terraform_Config)

repeat for team2-mgmt, team2-dev, team2-prod


## Comparision between CIOps and GitOps

- ToDo

## ToDo

- GarbageCollection?
