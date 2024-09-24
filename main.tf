terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

variable "LOAD_BALANCER_ARN" {
  type = string
  sensitive = true
}

variable "LOAD_BALANCER_DNS" {
  type = string
  sensitive = true
}

variable "AWS_COGNITO_ARN" {
  type = string
  sensitive = true
}

resource "aws_api_gateway_vpc_link" "main" {
	name = "menuguru-vpc-link"
 	target_arns = [var.LOAD_BALANCER_ARN]
}

resource "aws_api_gateway_rest_api" "main" {
	name = "menuguru_api"
 	endpoint_configuration {
   		types = ["REGIONAL"]
 }
}

resource "aws_api_gateway_authorizer" "menuguru_cognito" {
  name                   = "menuguru_cognito"
  rest_api_id            = aws_api_gateway_rest_api.main.id
  authorizer_uri         = "${var.AWS_COGNITO_ARN}"
  identity_source        = "method.request.header.Authorization"
  provider_arns          = [var.AWS_COGNITO_ARN]
  type                   = "COGNITO_USER_POOLS"
}

resource "aws_api_gateway_resource" "proxy" {
  	rest_api_id = aws_api_gateway_rest_api.main.id
  	parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  	path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  	rest_api_id   = aws_api_gateway_rest_api.main.id
  	resource_id   = aws_api_gateway_resource.proxy.id
  	http_method   = "ANY"
  	authorization = "COGNITO_USER_POOLS"
  	authorizer_id = aws_api_gateway_authorizer.menuguru_cognito.id

  	request_parameters = {
    	"method.request.path.proxy"           = true
    	"method.request.header.Authorization" = true
  }
}

resource "aws_api_gateway_integration" "proxy" {
  	rest_api_id = aws_api_gateway_rest_api.main.id
  	resource_id = aws_api_gateway_resource.proxy.id
  	http_method = "ANY"

  	integration_http_method = "ANY"
  	type                    = "HTTP_PROXY"
  	uri                     = "http://${var.LOAD_BALANCER_DNS}/{proxy}"
  	passthrough_behavior    = "WHEN_NO_MATCH"
  	content_handling        = "CONVERT_TO_TEXT"

  	request_parameters = {
	    "integration.request.path.proxy"           = "method.request.path.proxy"
    	"integration.request.header.Accept"        = "'application/json'"
    	"integration.request.header.Authorization" = "method.request.header.Authorization"
  	}

  	connection_type = "VPC_LINK"
  	connection_id   = aws_api_gateway_vpc_link.main.id
}

resource "aws_api_gateway_resource" "menuguru" {
  	rest_api_id = aws_api_gateway_rest_api.main.id
  	parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  	path_part   = "menuguru"
} 

resource "aws_api_gateway_resource" "v1" {
	rest_api_id = aws_api_gateway_rest_api.main.id
	parent_id   = aws_api_gateway_resource.menuguru.id
	path_part   = "v1"
}	

resource "aws_api_gateway_resource" "customers" {
  	rest_api_id = aws_api_gateway_rest_api.main.id
  	parent_id   = aws_api_gateway_resource.v1.id
  	path_part   = "customers"
}	
 	

resource "aws_api_gateway_method" "customer_post" {
  	rest_api_id   = aws_api_gateway_rest_api.main.id
  	resource_id   = aws_api_gateway_resource.customers.id
  	http_method   = "POST"
  	authorization = "NONE"

  	request_parameters = {
    	"method.request.path.proxy"  = true
  }
}

resource "aws_api_gateway_integration" "customer_post" {
  	rest_api_id = aws_api_gateway_rest_api.main.id
  	resource_id = aws_api_gateway_resource.customers.id
  	http_method = aws_api_gateway_method.customer_post.http_method

  	integration_http_method = "POST"
  	type                    = "HTTP_PROXY"
  	uri                     = "http://${var.LOAD_BALANCER_DNS}/menuguru/v1/customers"
  	passthrough_behavior    = "WHEN_NO_MATCH"
  	content_handling        = "CONVERT_TO_TEXT"

  	request_parameters = {
	    "integration.request.path.proxy"           = "method.request.path.proxy"
    	"integration.request.header.Accept"        = "'application/json'"
  	}

  	connection_type = "VPC_LINK"
  	connection_id   = aws_api_gateway_vpc_link.main.id
}

resource "aws_api_gateway_resource" "confirm_pay" {
  	rest_api_id = aws_api_gateway_rest_api.main.id
  	parent_id   = aws_api_gateway_resource.v1.id
  	path_part   = "orders"
}	


resource "aws_api_gateway_resource" "order_id" {
  	rest_api_id = aws_api_gateway_rest_api.main.id
  	parent_id   = aws_api_gateway_resource.confirm_pay.id
  	path_part   = "{proxy}"
}	
 
resource "aws_api_gateway_resource" "confirmPayment" {
  	rest_api_id = aws_api_gateway_rest_api.main.id
  	parent_id   = aws_api_gateway_resource.order_id.id
  	path_part   = "confirmPayment"
}	

resource "aws_api_gateway_method" "confirmPayment_post" {
  	rest_api_id   = aws_api_gateway_rest_api.main.id
  	resource_id   = aws_api_gateway_resource.confirmPayment.id
  	http_method   = "POST"
  	authorization = "NONE"

  	request_parameters = {
    	"method.request.path.proxy"  = true
  }
}

resource "aws_api_gateway_integration" "confirmPayment_post" {
  	rest_api_id = aws_api_gateway_rest_api.main.id
  	resource_id = aws_api_gateway_resource.confirmPayment.id
  	http_method = aws_api_gateway_method.confirmPayment_post.http_method

  	integration_http_method = "POST"
  	type                    = "HTTP_PROXY"
  	uri                     = "http://${var.LOAD_BALANCER_DNS}/menuguru/v1/orders/{proxy}/confirmPayment"
  	passthrough_behavior    = "WHEN_NO_MATCH"
  	content_handling        = "CONVERT_TO_TEXT"

  	request_parameters = {
	    "integration.request.path.proxy"           = "method.request.path.proxy"
    	"integration.request.header.Accept"        = "'application/json'"
  	}

  	connection_type = "VPC_LINK"
  	connection_id   = aws_api_gateway_vpc_link.main.id
}

resource "aws_api_gateway_stage" "prod_stage" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.main.id
  deployment_id = aws_api_gateway_deployment.deploy.id
}


resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.prod_stage.stage_name
  
  depends_on = [aws_api_gateway_method.proxy, aws_api_gateway_method.customers_post, aws_api_gateway_method.confirmPayment_post]
}