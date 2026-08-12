output "cluster_name" {
  value = module.eks.cluster_name
}

output "region" {
  value = var.region
}

output "karpenter_node_role_name" {
  description = "IAM Role created for dynamic Karpenter EC2 Spot instances"
  value       = module.karpenter.node_iam_role_name
}

output "kubectl_config_cmd" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "argocd_namespace" {
  description = "Kubernetes namespace where Argo CD is deployed"
  value       = helm_release.argocd.namespace
}

output "monitoring_namespace" {
  description = "Kubernetes namespace where kube-prometheus-stack is deployed"
  value       = helm_release.prometheus_stack.namespace
}