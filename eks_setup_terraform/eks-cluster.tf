module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "18.26.6"
  cluster_name    = local.cluster_name
  cluster_version = "1.20"
  
  #Cluster Networks
  vpc_id          = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnets

  tags = {
    Environment = "training"
    GithubRepo  = "terraform-aws-eks"
    GithubOrg   = "terraform-aws-modules"
  }

  eks_managed_node_group_defaults = {
    root_volume_type = "gp2"
    instance_types = ["t2.small"]
  }
  eks_managed_node_groups = {
    one = {
      name                    = "worker-group-1"
      instance_type           = "t2.small"
      desired_size            = 2
      pre_bootstrap_user_data = <<-EOT
      echo 'foo bar'
      EOT
       vpc_security_group_ids = [aws_security_group.worker_group_mgmt_one.id ]
    }

    #two = {
    #  name                    = "worker-group-2"
    #  instance_type           = "t2.medium"
    #  desired_size            = 1
    #  pre_bootstrap_user_data = <<-EOT
    #  echo 'foo bar'
    #  EOT
    #   vpc_security_group_ids = [aws_security_group.worker_group_mgmt_two.id] ]
    #}
  }
}
  
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}
