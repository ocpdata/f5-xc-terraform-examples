resource "volterra_cloud_credentials" "aws_cred" {
  count = var.aws_ce_site ? 1 : 0
  name      = format("%s-aws-creds-%s", local.project_prefix, local.build_suffix)
  namespace = "system"
  aws_secret_key {
    access_key = var.aws_access_key
    secret_key {
      clear_secret_info {
        url = "string:///${base64encode(var.aws_secret_key)}"
      }
    }
  }
}

# XC API deletes aws_vpc_site asynchronously: the DELETE call returns 200 but
# the object remains in XC's DB for ~30-60s. Without this delay, Terraform
# immediately proceeds to delete cloud_credentials and gets a 409 because
# XC still sees the vpc_site referencing the credentials.
# Destroy order enforced: vpc_site → this sleep → credentials
resource "null_resource" "wait_for_vpc_site_gc" {
  count      = var.aws_ce_site ? 1 : 0
  depends_on = [volterra_cloud_credentials.aws_cred]

  provisioner "local-exec" {
    when    = destroy
    command = "sleep 60"
  }
}

resource "volterra_aws_vpc_site" "aws_site" {
  count      = var.aws_ce_site ? 1 : 0
  depends_on = [volterra_cloud_credentials.aws_cred, null_resource.wait_for_vpc_site_gc]
  name       = "${coalesce(var.site_name, local.project_prefix)}"
  namespace  = "system"
  aws_region = local.aws_region
  aws_cred {
    name      = volterra_cloud_credentials.aws_cred[0].name
    namespace = "system"
  }
  instance_type = "t3.xlarge"
  vpc {
    vpc_id=local.vpc_id
  }
  ingress_egress_gw {
    aws_certified_hw = "aws-byol-multi-nic-voltmesh"
    az_nodes {
      aws_az_name = local.aws_ec2_azs
      disk_size   = 0
      outside_subnet {
        existing_subnet_id = local.aws_slo_subnet
      }
      inside_subnet {
        existing_subnet_id = local.aws_sli_subnet
      }
      workload_subnet {
        existing_subnet_id = local.aws_workload_subnet
      }
    }
  }
  logs_streaming_disabled = true
  no_worker_nodes         = true
  ssh_key = var.ssh_key
}


resource "null_resource" "validation-wait-aws-ce" {
  count = var.aws_ce_site ? 1 : 0
  provisioner "local-exec" {
    command = "sleep 70"
  }
}


resource "volterra_tf_params_action" "example" {
  count = var.aws_ce_site ? 1 : 0
  depends_on       = [null_resource.validation-wait-aws-ce]
  site_name        = volterra_aws_vpc_site.aws_site[0].name
  site_kind        = "aws_vpc_site"
  action           = "apply"
  wait_for_action  = true
}
