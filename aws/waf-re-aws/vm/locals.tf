locals {
  aws_region     = data.tfe_outputs.infra.values.aws_region
  project_prefix = data.tfe_outputs.infra.values.project_prefix
  resource_owner = data.tfe_outputs.infra.values.resource_owner
  build_suffix   = data.tfe_outputs.infra.values.build_suffix
  subnet_id      = data.tfe_outputs.infra.values.subnet_id
  sg_id          = data.tfe_outputs.infra.values.sg_id
}
