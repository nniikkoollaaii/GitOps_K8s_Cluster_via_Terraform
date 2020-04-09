
# Configure your K8s Cluster with Terraform

## Content of this Terraform Config

These folder contains a main.tf file. Here is all your Terraform config.

At first we are configuring the [Terraform Kubernetes Provider](https://www.terraform.io/docs/providers/kubernetes/index.html) to use our kubeconfig file

Then we are creating a "flux" namespace, a ConfigMap and a Secret to use with Flux (explained later)

Then we configure the Terraform Helm Provider to apply the [Helm Chart](https://github.com/fluxcd/flux/tree/master/chart/flux) provided by the Flux project to install Flux

I downloaded the helm chart to /terraform/flux
All Helm Values Config is in the Terraform Ressource "helm_release". I didn't modified the downlaoded helm chart

All configuration is done via the Helm values and the configmap and secret mentioned above

## Configure your terraform config

### Flux Git Auth

The secret "flux_git_auth" is used to allow Flux to access your git repository containing your k8s config

How to generate yourself an access token is explained [here](https://github.com/fluxcd/flux/blob/master/docs/guides/use-git-https.md)

Important: If your access token contains characters which need to be URL-escaped -> do so and use the result as "GIT_AUTHKEY" in the secret
Set "GIT_AUTHUSER" to your username

### Flux Certs

Flux accesses your git repo via https. The flux image contains certificates for the most common git repository servers like GitHub.
You can't disable ssl verification.
If you're using your private Git Server you have to include your certificate chain in the flux image's certificate store.

There are som options as described [here](https://github.com/fluxcd/flux/issues/1206#issuecomment-403783078)

I used the following way:

1. Startup the Flux image on your local machine

2. Copy your certificates (one certificate per file) to /usr/local/share/ca-certificates/\<name>.pem

3. Run 

    /usr/sbin/update-ca-certificates

3. Copy the generated ca-certificates.crt file from the container via

    kubectl cp flux/<pod>:/etc/ssl/certs/ca-certificates.crt ./ca-certificates.crt

4. The configmap "flux_certs" uses this exported file

5. At the bottom of the helm_release ressource I mounted the configmap as file to the correct path


### Configure the helm release

- set "git.url" to your git url

- set "git.user" to your username

- set "git.email" to your email

- add your private docker image mirror if used to "image.repository"

- disable the last five set-blocks if you aren't using a private git server

- disable the configmap if you aren't using a private git server

all available configurations are listed [here](https://github.com/fluxcd/flux/tree/master/chart/flux#configuration)

### apply terraform config

Go to your folder

    cd terraform

Initalize Terraform

    terraform init

Apply changes

    terraform apply

