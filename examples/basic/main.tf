terraform {
  required_version = ">= 1.6"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.28"
    }
  }
}

# Authenticate with the CLOUDFLARE_API_TOKEN environment variable.
provider "cloudflare" {}

variable "zone_id" {
  description = "Cloudflare zone ID of example.com."
  type        = string
}

module "wordpress_zone" {
  source = "../../modules/wordpress-zone"

  zone_id = var.zone_id

  dns_records = {
    apex = {
      name    = "@"
      type    = "A"
      content = "203.0.113.10"
      proxied = true
      comment = "WordPress origin"
    }
    apex_v6 = {
      name    = "@"
      type    = "AAAA"
      content = "2001:db8::10"
      proxied = true
    }
    www = {
      name    = "www"
      type    = "CNAME"
      content = "example.com"
      proxied = true
    }

    # Email: DNS-only, copied from your current provider. Never proxy these.
    mail_host = {
      name    = "mail"
      type    = "A"
      content = "203.0.113.20"
      proxied = false
    }
    mx_primary = {
      name     = "@"
      type     = "MX"
      content  = "mail.example.com"
      priority = 10
    }
    spf = {
      name    = "@"
      type    = "TXT"
      content = "v=spf1 mx a:mail.example.com -all"
    }
    dkim = {
      name    = "default._domainkey"
      type    = "TXT"
      content = "v=DKIM1; k=rsa; p=REPLACE_WITH_YOUR_PUBLIC_KEY"
    }
    dmarc = {
      name    = "_dmarc"
      type    = "TXT"
      content = "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com"
    }
  }
}

output "dns_only_records" {
  value = module.wordpress_zone.dns_only_dns_records
}

output "proxied_records" {
  value = module.wordpress_zone.proxied_dns_records
}
