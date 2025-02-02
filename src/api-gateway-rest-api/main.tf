locals {
  is_edge     = var.endpoint_configuration == "EDGE"
  is_regional = var.endpoint_configuration == "REGIONAL"
}

resource "aws_api_gateway_rest_api" "main" {
  name = var.name

  endpoint_configuration {
    types = [var.endpoint_configuration]
  }
}

resource "aws_api_gateway_resource" "health_check" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "_health"
}

resource "aws_api_gateway_method" "health_check" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.health_check.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "health_check" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.health_check.id
  http_method = aws_api_gateway_method.health_check.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = <<EOF
    {
      "statusCode": 200
    }
EOF
  }
}

resource "aws_api_gateway_method_response" "success" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.health_check.id
  http_method = aws_api_gateway_method.health_check.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "health_check" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.health_check.id
  http_method = aws_api_gateway_method.health_check.http_method
  status_code = aws_api_gateway_method_response.success.status_code
}

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  depends_on = [aws_api_gateway_method_response.success]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.stage_name
}

resource "aws_api_gateway_domain_name" "main" {
  count                    = var.dns_enabled ? 1 : 0
  certificate_arn          = local.is_edge ? var.certificate_arn : null
  regional_certificate_arn = local.is_regional ? var.certificate_arn : null
  domain_name              = var.domain

  endpoint_configuration {
    types = [var.endpoint_configuration]
  }
}

moved {
  from = aws_api_gateway_domain.main
  to   = aws_api_gateway_domain.main[0]
}

resource "aws_api_gateway_base_path_mapping" "main" {
  count       = var.dns_enabled ? 1 : 0
  api_id      = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  domain_name = aws_api_gateway_domain_name.main[0].domain_name
}

moved {
  from = aws_api_gateway_base_path_mapping.main
  to   = aws_api_gateway_base_path_mapping.main[0]
}

resource "aws_route53_record" "main" {
  count   = var.dns_enabled ? 1 : 0
  name    = var.domain
  type    = "A"
  zone_id = var.hosted_zone_id

  alias {
    evaluate_target_health = true
    name                   = local.is_regional ? aws_api_gateway_domain_name.main[0].regional_domain_name : aws_api_gateway_domain_name.main[0].cloudfront_domain_name
    zone_id                = local.is_regional ? aws_api_gateway_domain_name.main[0].regional_zone_id : aws_api_gateway_domain_name.main[0].cloudfront_zone_id
  }
}

moved {
  from = aws_route53_record.main
  to   = aws_route53_record.main[0]
}