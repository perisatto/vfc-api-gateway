variable "REQUEST_LOAD_BALANCER_ARN" {
  type = string
  sensitive = true
}

variable "REQUEST_LOAD_BALANCER_DNS" {
  type = string
  sensitive = true
}

resource "aws_api_gateway_vpc_link" "request" {
	name = "request-vpc-link"
 	target_arns = [var.REQUEST_LOAD_BALANCER_ARN]
}

resource "aws_api_gateway_rest_api" "request" {
	name = "request_manager_api"
 	endpoint_configuration {
   		types = ["REGIONAL"]
 }
}

resource "aws_api_gateway_authorizer" "vfc_request_auth" {
  name                   = "vfc_request_auth"
  rest_api_id            = aws_api_gateway_rest_api.request.id
  authorizer_uri         = "${var.AWS_COGNITO_ARN}"
  identity_source        = "method.request.header.Authorization"
  provider_arns          = [var.AWS_COGNITO_ARN]
  type                   = "COGNITO_USER_POOLS"
}

resource "aws_api_gateway_resource" "request_proxy" {
  	rest_api_id = aws_api_gateway_rest_api.request.id
  	parent_id   = aws_api_gateway_rest_api.request.root_resource_id
  	path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "request_proxy" {
  	rest_api_id   = aws_api_gateway_rest_api.request.id
  	resource_id   = aws_api_gateway_resource.request_proxy.id
  	http_method   = "ANY"
  	authorization = "COGNITO_USER_POOLS"
  	authorizer_id = aws_api_gateway_authorizer.vfc_request_auth.id

  	request_parameters = {
    	"method.request.path.proxy"           = true
    	"method.request.header.Authorization" = true
  }
}

resource "aws_api_gateway_integration" "request_proxy" {
  	rest_api_id = aws_api_gateway_rest_api.request.id
  	resource_id = aws_api_gateway_resource.request_proxy.id
  	http_method = "ANY"

  	integration_http_method = "ANY"
  	type                    = "HTTP_PROXY"
  	uri                     = "http://${var.REQUEST_LOAD_BALANCER_DNS}/{proxy}"
  	passthrough_behavior    = "WHEN_NO_MATCH"
  	content_handling        = "CONVERT_TO_TEXT"

  	request_parameters = {
	    "integration.request.path.proxy"           = "method.request.path.proxy"
    	"integration.request.header.Accept"        = "'application/json'"
    	"integration.request.header.Authorization" = "method.request.header.Authorization"
  	}

  	connection_type = "VPC_LINK"
  	connection_id   = aws_api_gateway_vpc_link.request.id
}

resource "aws_api_gateway_deployment" "request_deploy" {
  rest_api_id = aws_api_gateway_rest_api.request.id
  stage_name  = "prod"
  
  depends_on = [aws_api_gateway_method.request_proxy,   
  				aws_api_gateway_integration.request_proxy]
}