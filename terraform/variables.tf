variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-2"
}

variable "cluster_name" {
  description = "Name of the EKS Cluster"
  type        = string
  default     = "scale-to-zero-eks"
}

variable "kubernetes_version" {
  description = "Standard support Kubernetes version to prevent extended support surcharges"
  type        = string
  default     = "1.34"
}