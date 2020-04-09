provider "kubernetes" {
    config_path = "./kind-kubeconfig"
}

resource "kubernetes_namespace" "gitops_namespace" {
  metadata {
    name = "gitops"
  }
}

resource "kubernetes_secret" "flux_git_auth" {
  metadata {
    name = "flux-git-auth"
    namespace = kubernetes_namespace.gitops_namespace.metadata[0].name
  }
  data = {
    GIT_AUTHUSER = var.git_username
    #unescaped: <auth-key>
    GIT_AUTHPASSWORD = var.git_password

  }
  type = "Opaque"
}

resource "kubernetes_secret" "git_auth" {
  metadata {
    name = "git-auth"
    namespace = kubernetes_namespace.gitops_namespace.metadata[0].name
  }
  data = {
    username = var.git_username
    #unescaped: <auth-key>
    password = var.git_password

  }
  type = "Opaque"
}

#resource "kubernetes_config_map" "flux_certs" {
#  metadata {
#    name = "flux-certs"
#    namespace = kubernetes_namespace.gitops_namespace.metadata[0].name
#  }
#  data = {
#    "ca-certificates.crt" ="${file("${path.module}/ca-certificates.crt")}" 
#  }
#}

provider "helm" {
  kubernetes {
    config_path = "./kind-kubeconfig"
  }
}

resource "helm_release" "flux" {
  name  = "flux"
  chart = "../helm/flux"
  namespace = kubernetes_namespace.gitops_namespace.metadata[0].name

  timeout = 180

  set {
    name  = "image.repository"
    value = "fluxcd/flux"
  }

  set {
    name  = "git.url"
    value = "https://$(GIT_AUTHUSER):$(GIT_AUTHKEY)@github.com/nniikkoollaaii/GitOps_K8s_Cluster_via_Terraform_Config.git"
  }

  set {
    name  = "git.branch"
    value = "master"
  }

  set {
    name  = "git.user"
    value = "nniikkoollaaii"
  }

  set {
    name  = "git.email"
    value = "<email>"
  }

  set {
    name = "git.pollInterval"
    value = "1m"
  }

  set {
    name  = "env.secretName"
    value = "flux-git-auth"
  }

  set {
    name  = "memcached.repository"
    value = "memcached"
  }

set {
    name  = "registry.disableScanning"
    value = "true"
  }

###################################################
#mount certificates for private repository server
#  set {
#    name = "extraVolumeMounts[0].name"
#    value = "certs"
#  }
#  set {
#    name = "extraVolumeMounts[0].mountPath"
#    value = "/etc/ssl/certs"
#  }
#  set {
#    name = "extraVolumes[0].name"
#    value = "certs"
#  }
#  set {
#    name = "extraVolumes[0].configMap.name"
#    value = "flux-certs"
#  }
#  set {
#    name = "extraVolumes[0].configMap.defaultMode"
#    value = 0400
#  }
###################################################
  
}


########################################################################
# Helm Release for Helm Operator CRDs
########################################################################

resource "helm_release" "helm-operator-crd" {
  name  = "helm-operator-crd"
  chart = "../helm/helm-operator-crd"

  timeout = 180

}

########################################################################
# Helm Release for Helm Operator
########################################################################

resource "helm_release" "helm-operator" {
  name  = "helm-operator"
  chart = "../helm/helm-operator"
  namespace = kubernetes_namespace.gitops_namespace.metadata[0].name

  depends_on = [
    helm_release.helm-operator-crd,
  ]
  timeout = 180

  set {
    name  = "image.repository"
    value = "fluxcd/helm-operator"
  }

  set {
    name  = "image.tag"
    value = "1.0.0"
  }

  set {
    name  = "helm.versions"
    value = "v3"
  }

  
  set {
    name  = "allowNamespace"
    value = kubernetes_namespace.gitops_namespace.metadata[0].name
  }

    set {
    name = "git.pollInterval"
    value = "1m"
  }

}
