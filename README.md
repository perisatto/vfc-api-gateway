# MenuGuru

Este repositório contém os scripts de Terraform para o Api Gateway da aplicação [Menuguru](https://github.com/perisatto/menuguru), que implementa um sistema fictício de gestão de pedidos para restaurantes como parte do trabalho de avaliação do curso de Pós Graduação em Software Architecture da FIAP.

O MenuGuru tem como objetivo principal registrar e acompanhar o status de pedidos para restaurantes, onde o cliente pode realizar seu pedido e acompanhar o status do mesmo até a retirada.

Funcionalidades:
* Cadastro e Identificação de Clientes
* Gestão de Produtos (criação, consulta, edição e remoção)
* Gestão de Pedidos (solicitação, consulta e finalização de pedidos)
* Integração com Mercado Pago para processamento dos pagamentos

# Guia para execução do projeto

## Pré-Requisitos

* Terraform CLI
* AWS CLI

## Execução

1. Execute o comando para inicializar o Terraform

``` bash
$ terraform init
```

2. Execute o comando para validação dos scripts

``` bash
$ terraform validate
```

3. Execute o comando para aplicar as alterações

``` bash
$ terraform apply
```

.