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
        api_key = {
          key = aws_api_gateway_api_key.api_key.value
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
  name                 = "Api Authentication: ${var.md_metadata.name_prefix}"
  artifact = jsonencode(
    {
      data = {
        api = {
          hostname = var.dns.enabled ? "${var.dns.sub_domain}.${data.aws_route53_zone.lookup[0].name}" : "${local.api_id}.execute-api.${var.rest_api.region}.amazonaws.com/${var.rest_api.stage_name}"
          port     = 443
          protocol = "https"
        }
        etc = {
          api_key = aws_api_gateway_api_key.api_key.value
        }
      }
      specs = {
        api = {
          version = "1"
        }
        aws = {
          region = var.rest_api.region
        }
      }
    }
  )
}
