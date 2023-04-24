locals {
  fq_domain             = var.dns.enabled ? "${var.dns.sub_domain}.${data.aws_route53_zone.lookup[0].name}" : ""
  config_is_regional    = var.rest_api.endpoint_configuration == "REGIONAL"
  config_is_edge        = var.rest_api.endpoint_configuration == "EDGE"
  regional_or_edge_cert = var.dns.enabled ? (local.config_is_regional ? module.acm_regional_certificate[0].certificate_arn : module.acm_edge_certificate[0].certificate_arn) : ""
  hosted_zone_id        = var.dns.enabled ? split("/", var.dns.hosted_zone)[1] : ""
  api_id                = reverse(split("/", data.aws_arn.api_gateway_main.resource))[0]
}

data "aws_route53_zone" "lookup" {
  count   = var.dns.enabled ? 1 : 0
  zone_id = local.hosted_zone_id
}

module "acm_edge_certificate" {
  count          = local.config_is_edge && var.dns.enabled ? 1 : 0
  source         = "github.com/massdriver-cloud/terraform-modules//aws/acm-certificate?ref=21b84cd"
  domain_name    = local.fq_domain
  hosted_zone_id = local.hosted_zone_id
  providers = {
    aws = aws.useast1
  }
}

module "acm_regional_certificate" {
  count          = local.config_is_regional && var.dns.enabled ? 1 : 0
  source         = "github.com/massdriver-cloud/terraform-modules//aws/acm-certificate?ref=21b84cd"
  domain_name    = local.fq_domain
  hosted_zone_id = local.hosted_zone_id
}

module "api_gateway" {
  source                 = "./api-gateway-rest-api"
  name                   = var.md_metadata.name_prefix
  endpoint_configuration = var.rest_api.endpoint_configuration
  domain                 = local.fq_domain
  hosted_zone_id         = local.hosted_zone_id
  certificate_arn        = local.regional_or_edge_cert
  stage_name             = var.rest_api.stage_name
  dns_enabled            = var.dns.enabled

  depends_on = [module.acm_edge_certificate, module.acm_regional_certificate]
}

resource "aws_api_gateway_api_key" "api_key" {
  name = "api_key"
}

data "aws_arn" "api_gateway_main" {
  arn = module.api_gateway.arn
}

resource "aws_api_gateway_usage_plan" "usage_plan" {
  name = "usage_plan"

  api_stages {
    api_id = local.api_id
    stage  = module.api_gateway.stage_name
  }
}

resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.usage_plan.id
}
