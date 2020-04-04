variable "name" {
  description = "A unique name for this deployment."
}

variable "kubernetes_namespace" {}

variable "user_names" {
  type = list(string)
}

variable "user_config" {
  type = "string"
}

variable "domain_names" {
  type = list(string)
}

variable "pvc_storage_class" {
  default = "default"
}

variable "pvc_access_modes" {
  default = [
    "ReadWriteOnce"
  ]
}

variable "pvc_storage_size" {}

variable "labels" {
  type = map(string)
  default = {}
  description = "Additional labels to assign to kubernetes resources."
}

variable "selectors" {
  type = map(string)
  default = {}
  description = "Additional selectors used to find kubernetes resources."
}

variable "cluster_issuer" {
  default = "letsencrypt-staging"
}

variable "ingress_class" {
  default = "nginx"
}

variable "sftp_port" {
  description = "A kubernetes NodePort to allow sftp connections to."
}
