locals {
  labels = merge(var.labels, {
    app: "ftp-website"
    deploymentName: var.name,
  })

  selectors = merge(var.selectors, {
    app: "ftp-website"
    deploymentName: var.name,
  })
}

resource "tls_private_key" "server_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_private_key" "server_ssh_ecdsa_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "kubernetes_deployment" "website" {
  metadata {
    name = "${var.name}-ftp-website"
    namespace = var.kubernetes_namespace
    labels = local.labels
  }
  spec {
    selector {
      match_labels = local.selectors
    }
    template {
      metadata {
        labels = local.labels
      }
      spec {
        volume {
          name = "users"
          secret {
            secret_name = kubernetes_secret.config.metadata[0].name
            items {
              key = "users.conf"
              path = "users.conf"
            }
          }
        }

        volume {
          name = "ssh"
          secret {
            default_mode = "0600"
            secret_name = kubernetes_secret.config.metadata[0].name

            items {
              key = "ssh_host_rsa_key"
              path = "ssh_host_rsa_key"
            }

            items {
              key = "ssh_host_ed25519_key"
              path = "ssh_host_ed25519_key"
            }
          }
        }

        volume {
          name = "files"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.files.metadata[0].name
          }
        }

        init_container {
          name = "init"
          image = "busybox:1.31"

          command = ["chown", "-R", "6:6", "/usr/share/nginx/html"]

          volume_mount {
            mount_path = "/usr/share/nginx/html"
            name = "files"
            sub_path = "files"
          }
        }

        container {
          name = "nginx"
          image = "nginx:1.17"

          port {
            container_port = 80
          }

          liveness_probe {
            tcp_socket {
              port = 80
            }
          }

          volume_mount {
            mount_path = "/usr/share/nginx/html"
            name = "files"
            sub_path = "files"
          }
        }

        container {
          name = "sftp"
          image = "atmoz/sftp"

          port {
            container_port = 22
          }

          liveness_probe {
            tcp_socket {
              port = 22
            }
          }

          volume_mount {
            name = "users"
            mount_path = "/etc/sftp/users.conf"
            sub_path = "users.conf"
          }

          volume_mount {
            name = "ssh"
            mount_path = "/etc/ssh/ssh_host_rsa_key"
            sub_path = "ssh_host_rsa_key"
          }

          volume_mount {
            name = "ssh"
            mount_path = "/etc/ssh/ssh_host_ed25519_key"
            sub_path = "ssh_host_ed25519_key"
          }

          dynamic "volume_mount" {
            for_each = var.user_names

            content {
              mount_path = "/home/${volume_mount.value}/html"
              name = "files"
              sub_path = "files"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_secret" "config" {
  metadata {
    name = "${var.name}-ftp-website"
    namespace = var.kubernetes_namespace
    labels = local.labels
  }

  data = {
    "users.conf" = var.user_config
    ssh_host_rsa_key = tls_private_key.server_ssh_key.private_key_pem
    ssh_host_ed25519_key = tls_private_key.server_ssh_ecdsa_key.private_key_pem
  }
}

resource "kubernetes_persistent_volume_claim" "files" {
  metadata {
    name = "${var.name}-ftp-website"
    namespace = var.kubernetes_namespace
    labels = local.labels
  }
  spec {
    access_modes = var.pvc_access_modes
    storage_class_name = var.pvc_storage_class
    resources {
      requests = {
        storage = var.pvc_storage_size
      }
    }
  }
}

resource "kubernetes_service" "website" {
  metadata {
    name = "${var.name}-ftp-website-http"
    namespace = var.kubernetes_namespace
    labels = local.labels
  }
  spec {
    type = "ClusterIP"
    selector = local.selectors

    port {
      port = 80
    }
  }
}

resource "kubernetes_service" "sftp" {
  metadata {
    name = "${var.name}-ftp-website-sftp"
    namespace = var.kubernetes_namespace
    labels = local.labels
  }
  spec {
    type = "ClusterIP"

    port {
      port = 22
      target_port = 22
    }
    selector = local.selectors
  }
}

resource "kubernetes_ingress" "webserver" {
  metadata {
    name = "${var.name}-ftp-website-http"
    namespace = var.kubernetes_namespace
    labels = local.labels
    annotations = {
      "kubernetes.io/ingress.class" = var.ingress_class
      "certmanager.k8s.io/cluster-issuer" = var.cluster_issuer
      "kubernetes.io/tls-acme" = "true"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
    }
  }
  spec {
    tls {
      hosts = var.domain_names
      secret_name = "${var.name}-certs"
    }

    dynamic "rule" {
      for_each = var.domain_names
      content {
        host = rule.value
        http {
          path {
            backend {
              service_name = kubernetes_service.website.metadata[0].name
              service_port = 80
            }
          }
        }
      }
    }

  }
}
