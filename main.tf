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

variable "AWS_COGNITO_ARN" {
  type = string
  sensitive = true
}

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


resource "aws_api_gateway_resource" "request_manager" {
  	rest_api_id = aws_api_gateway_rest_api.request.id
  	parent_id   = aws_api_gateway_rest_api.request.root_resource_id
  	path_part   = "user-management"
} 

resource "aws_api_gateway_resource" "request_v1" {
	rest_api_id = aws_api_gateway_rest_api.request.id
	parent_id   = aws_api_gateway_resource.request_manager.id
	path_part   = "v1"
}	

resource "aws_api_gateway_resource" "request_users" {
  	rest_api_id = aws_api_gateway_rest_api.request.id
  	parent_id   = aws_api_gateway_resource.request_v1.id
  	path_part   = "users"
}

resource "aws_api_gateway_resource" "request_me" {
  	rest_api_id = aws_api_gateway_rest_api.request.id
  	parent_id   = aws_api_gateway_resource.request_users.id
  	path_part   = "me"
}

resource "aws_api_gateway_resource" "request" {
  	rest_api_id = aws_api_gateway_rest_api.request.id
  	parent_id   = aws_api_gateway_resource.request_me.id
  	path_part   = "requests"
}

resource "aws_api_gateway_resource" "request_proxy" {
  	rest_api_id = aws_api_gateway_rest_api.request.id
  	parent_id   = aws_api_gateway_resource.request.id
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

variable "USER_LOAD_BALANCER_ARN" {
  type = string
  sensitive = true
}

variable "USER_LOAD_BALANCER_DNS" {
  type = string
  sensitive = true
}

resource "aws_api_gateway_vpc_link" "user" {
	name = "user-vpc-link"
 	target_arns = [var.USER_LOAD_BALANCER_ARN]
}

resource "aws_api_gateway_rest_api" "user" {
	name = "user_management_api"
 	endpoint_configuration {
   		types = ["REGIONAL"]
 }
}

resource "aws_api_gateway_authorizer" "vfc_user_auth" {
  name                   = "vfc_user_auth"
  rest_api_id            = aws_api_gateway_rest_api.user.id
  authorizer_uri         = "${var.AWS_COGNITO_ARN}"
  identity_source        = "method.request.header.Authorization"
  provider_arns          = [var.AWS_COGNITO_ARN]
  type                   = "COGNITO_USER_POOLS"
}

resource "aws_api_gateway_resource" "user_proxy" {
  	rest_api_id = aws_api_gateway_rest_api.user.id
  	parent_id   = aws_api_gateway_rest_api.user.root_resource_id
  	path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "user_proxy" {
  	rest_api_id   = aws_api_gateway_rest_api.user.id
  	resource_id   = aws_api_gateway_resource.user_proxy.id
  	http_method   = "ANY"
  	authorization = "COGNITO_USER_POOLS"
  	authorizer_id = aws_api_gateway_authorizer.vfc_user_auth.id

  	request_parameters = {
    	"method.request.path.proxy"           = true
    	"method.request.header.Authorization" = true
  }
}

resource "aws_api_gateway_integration" "user_proxy" {
  	rest_api_id = aws_api_gateway_rest_api.user.id
  	resource_id = aws_api_gateway_resource.user_proxy.id
  	http_method = "ANY"

  	integration_http_method = "ANY"
  	type                    = "HTTP_PROXY"
  	uri                     = "http://${var.USER_LOAD_BALANCER_DNS}/{proxy}"
  	passthrough_behavior    = "WHEN_NO_MATCH"
  	content_handling        = "CONVERT_TO_TEXT"

  	request_parameters = {
	    "integration.request.path.proxy"           = "method.request.path.proxy"
    	"integration.request.header.Accept"        = "'application/json'"
    	"integration.request.header.Authorization" = "method.request.header.Authorization"
  	}

  	connection_type = "VPC_LINK"
  	connection_id   = aws_api_gateway_vpc_link.user.id
}

resource "aws_api_gateway_resource" "user_management" {
  	rest_api_id = aws_api_gateway_rest_api.user.id
  	parent_id   = aws_api_gateway_rest_api.user.root_resource_id
  	path_part   = "user-management"
} 

resource "aws_api_gateway_resource" "user_v1" {
	rest_api_id = aws_api_gateway_rest_api.user.id
	parent_id   = aws_api_gateway_resource.user_management.id
	path_part   = "v1"
}	

resource "aws_api_gateway_resource" "users" {
  	rest_api_id = aws_api_gateway_rest_api.user.id
  	parent_id   = aws_api_gateway_resource.user_v1.id
  	path_part   = "users"
}	
 	

resource "aws_api_gateway_method" "users_post" {
  	rest_api_id   = aws_api_gateway_rest_api.user.id
  	resource_id   = aws_api_gateway_resource.users.id
  	http_method   = "POST"
  	authorization = "NONE"

  	request_parameters = {
    	"method.request.path.proxy"  = true
  }
}

resource "aws_api_gateway_integration" "user_post" {
  	rest_api_id = aws_api_gateway_rest_api.user.id
  	resource_id = aws_api_gateway_resource.users.id
  	http_method = aws_api_gateway_method.users_post.http_method

  	integration_http_method = "POST"
  	type                    = "HTTP_PROXY"
  	uri                     = "http://${var.USER_LOAD_BALANCER_DNS}/user-management/v1/users"
  	passthrough_behavior    = "WHEN_NO_MATCH"
  	content_handling        = "CONVERT_TO_TEXT"

  	request_parameters = {
	    "integration.request.path.proxy"           = "method.request.path.proxy"
    	"integration.request.header.Accept"        = "'application/json'"
  	}

  	connection_type = "VPC_LINK"
  	connection_id   = aws_api_gateway_vpc_link.user.id
}

resource "aws_api_gateway_deployment" "user_deploy" {
  rest_api_id = aws_api_gateway_rest_api.user.id
  stage_name  = "prod"
  
  depends_on = [aws_api_gateway_method.user_proxy, 
  				aws_api_gateway_method.users_post,  
  				aws_api_gateway_integration.user_post]
}