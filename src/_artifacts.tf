resource "massdriver_artifact" "api_gateway" {
  field                = "api_gateway"
  provider_resource_id = module.api_gateway.arn
  name                 = "Api Gateway: ${var.md_metadata.name_prefix}"
  artifact = jsonencode(
    {
      data = {
        infrastructure = {
          arn              = module.api_gateway.arn
          stage_arn        = module.api_gateway.stage_arn
          root_resource_id = module.api_gateway.root_resource_id
        }
      }
      specs = {
        aws = {
          region = var.rest_api.region
        }
      }
    }
  )
}

resource "massdriver_artifact" "api" {
  field                = "api"
  provider_resource_id = module.api_gateway.arn
  name                 = "Api: ${var.md_metadata.name_prefix}"
  artifact = jsonencode(
    {
      data = {
        api = {
          hostname = "${local.fq_domain}"
          port     = 443
          protocol = "https"
        }
        extra = {
          fq_domain = "${local.fq_domain}"
          url     = "https://${local.fq_domain}:443"
          api_key = resource.aws_api_gateway_api_key.api_key.value
        }
      }
      specs = {
        api = {
          version = "v1"
        }
        aws = {
          region = var.rest_api.region
        }
      }
    }
  )
}
