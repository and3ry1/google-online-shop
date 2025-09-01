# Créer le fichier principal Terraform
terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

provider "github" {
  token = var.github_token
  owner = var.github_org
}

variable "github_token" {
  description = "GitHub Personal Access Token"
  type        = string
  sensitive   = true
}

variable "github_org" {
  description = "GitHub Organization name"
  type        = string
  default     = "online-boutique-org"
}

variable "services" {
  description = "Microservices to create repositories for"
  type        = list(object({
    name        = string
    description = string
    language    = string
  }))
  default = [
    { name = "frontend", description = "Frontend service for Online Boutique", language = "Go" },
    { name = "cartservice", description = "Cart management service", language = "C#" },
    { name = "productcatalogservice", description = "Product catalog service", language = "Go" },
    { name = "currencyservice", description = "Currency conversion service", language = "Node.js" },
    { name = "paymentservice", description = "Payment processing service", language = "Node.js" },
    { name = "shippingservice", description = "Shipping cost calculation service", language = "Go" },
    { name = "emailservice", description = "Email notification service", language = "Python" },
    { name = "checkoutservice", description = "Order checkout service", language = "Go" },
    { name = "recommendationservice", description = "Product recommendation service", language = "Python" },
    { name = "adservice", description = "Advertisement service", language = "Java" },
    { name = "loadgenerator", description = "Load generation service", language = "Python" }
  ]
}

# Création des dépôts pour chaque service
resource "github_repository" "service_repo" {
  for_each = { for service in var.services : service.name => service }
  
  name        = "${each.key}-service"
  description = each.value.description
  visibility  = "public"
  
  has_issues      = true
  has_projects    = false
  has_wiki        = false
  has_downloads   = false
  
  auto_init       = true
  gitignore_template = lookup({
    "Go" = "Go",
    "C#" = "csharp",
    "Node.js" = "Node",
    "Python" = "Python",
    "Java" = "Java"
  }, each.value.language, "")
  
  vulnerability_alerts = true
}

# Création du dépôt des protos partagés
resource "github_repository" "proto_repo" {
  name        = "proto-definitions"
  description = "Shared Protocol Buffer definitions for Online Boutique microservices"
  visibility  = "public"
  
  has_issues      = true
  has_projects    = false
  has_wiki        = false
  has_downloads   = false
  
  auto_init       = true
}

# Création du dépôt d'infrastructure
resource "github_repository" "infra_repo" {
  name        = "infrastructure"
  description = "Infrastructure as Code for Online Boutique"
  visibility  = "public"
  
  has_issues      = true
  has_projects    = false
  has_wiki        = false
  has_downloads   = false
  
  auto_init       = true
}

output "repositories" {
  value = [for repo in github_repository.service_repo : repo.html_url]
}
EOF# Créer le fichier principal Terraform
cat > terraform/main.tf << 'EOF'
terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

provider "github" {
  token = var.github_token
  owner = var.github_org
}

variable "github_token" {
  description = "GitHub Personal Access Token"
  type        = string
  sensitive   = true
}

variable "github_org" {
  description = "GitHub Organization name"
  type        = string
  default     = "online-boutique-org"
}

variable "services" {
  description = "Microservices to create repositories for"
  type        = list(object({
    name        = string
    description = string
    language    = string
  }))
  default = [
    { name = "frontend", description = "Frontend service for Online Boutique", language = "Go" },
    { name = "cartservice", description = "Cart management service", language = "C#" },
    { name = "productcatalogservice", description = "Product catalog service", language = "Go" },
    { name = "currencyservice", description = "Currency conversion service", language = "Node.js" },
    { name = "paymentservice", description = "Payment processing service", language = "Node.js" },
    { name = "shippingservice", description = "Shipping cost calculation service", language = "Go" },
    { name = "emailservice", description = "Email notification service", language = "Python" },
    { name = "checkoutservice", description = "Order checkout service", language = "Go" },
    { name = "recommendationservice", description = "Product recommendation service", language = "Python" },
    { name = "adservice", description = "Advertisement service", language = "Java" },
    { name = "loadgenerator", description = "Load generation service", language = "Python" }
  ]
}

# Création des dépôts pour chaque service
resource "github_repository" "service_repo" {
  for_each = { for service in var.services : service.name => service }
  
  name        = "${each.key}-service"
  description = each.value.description
  visibility  = "public"
  
  has_issues      = true
  has_projects    = false
  has_wiki        = false
  has_downloads   = false
  
  auto_init       = true
  gitignore_template = lookup({
    "Go" = "Go",
    "C#" = "csharp",
    "Node.js" = "Node",
    "Python" = "Python",
    "Java" = "Java"
  }, each.value.language, "")
  
  vulnerability_alerts = true
}

# Création du dépôt des protos partagés
resource "github_repository" "proto_repo" {
  name        = "proto-definitions"
  description = "Shared Protocol Buffer definitions for Online Boutique microservices"
  visibility  = "public"
  
  has_issues      = true
  has_projects    = false
  has_wiki        = false
  has_downloads   = false
  
  auto_init       = true
}

# Création du dépôt d'infrastructure
resource "github_repository" "infra_repo" {
  name        = "infrastructure"
  description = "Infrastructure as Code for Online Boutique"
  visibility  = "public"
  
  has_issues      = true
  has_projects    = false
  has_wiki        = false
  has_downloads   = false
  
  auto_init       = true
}

output "repositories" {
  value = [for repo in github_repository.service_repo : repo.html_url]
}
EOF
