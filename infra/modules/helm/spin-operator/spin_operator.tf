resource "kubernetes_namespace" "spin_operator" {
  metadata {
    name = var.namespace
  }
}

# TODO: fetch from canonical source or GH release, etc
resource "kubectl_manifest" "spin_operator_crds" {
    yaml_body = file("${path.module}/crds.yaml")
}

resource "helm_release" "spin_operator" {
  name       = "spin-operator"
  repository = "oci://ghcr.io/spinkube"
  chart      = "spin-operator"
  devel     = true
  wait      = true
  namespace = kubernetes_namespace.spin_operator.metadata.0.name

  depends_on = [
    kubectl_manifest.spin_operator_crds
  ]
}
