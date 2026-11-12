output "vpc_id" {
  description = "Demo VPC ID"
  value       = aws_vpc.this.id
}

output "nat_public_ip" {
  description = "Public egress IP of the fck-nat instance"
  value       = aws_instance.fck_nat.public_ip
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "kubeconfig_command" {
  description = "Command that adds the cluster to ~/.kube/config"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.this.name}"
}

output "kubernetes_namespace" {
  description = "Namespace holding the Connector releases and the demo service"
  value       = kubernetes_namespace_v1.this.metadata[0].name
}

output "connector_names" {
  description = "Twingate Connector names"
  value       = twingate_connector.this[*].name
}

output "connector_release_names" {
  description = "Helm release names running the Connectors"
  value       = helm_release.connector[*].name
}

output "twingate_resource_address" {
  description = "Address to reach through the Twingate Client"
  value       = twingate_resource.private_resource.address
}

output "service_account_key" {
  description = "Service account key token (null unless tg_create_service_account = true)"
  value       = one(twingate_service_account_key.this[*].token)
  sensitive   = true
}
