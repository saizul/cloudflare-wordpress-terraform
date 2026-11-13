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
  description = "Cloudflare zone ID of shop.example.com's parent zone."
  type        = string
}

module "woocommerce_zone" {
  source = "../../modules/wordpress-zone"

  zone_id = var.zone_id

  dns_records = {
    apex = {
      name    = "@"
      type    = "A"
      content = "203.0.113.10"
      proxied = true
    }
    www = {
      name    = "www"
      type    = "CNAME"
      content = "example.com"
      proxied = true
    }
    mx_primary = {
      name     = "@"
      type     = "MX"
      content  = "mx1.mail.example.net"
      priority = 10
    }
    mx_secondary = {
      name     = "@"
      type     = "MX"
      content  = "mx2.mail.example.net"
      priority = 20
    }
    spf = {
      name    = "@"
      type    = "TXT"
      content = "v=spf1 include:_spf.mail.example.net -all"
    }
    dkim = {
      name    = "selector1._domainkey"
      type    = "TXT"
      content = "v=DKIM1; k=rsa; p=REPLACE_WITH_YOUR_PUBLIC_KEY"
    }
    dmarc = {
      name    = "_dmarc"
      type    = "TXT"
      content = "v=DMARC1; p=reject; rua=mailto:dmarc@example.com"
    }
  }

  # TLS: origin must present a valid certificate (Let's Encrypt or Cloudflare Origin CA).
  ssl_mode        = "strict"
  min_tls_version = "1.2"

  # Localised store pages: add your translated slugs to the bypass list.
  cache_bypass_paths = [
    "/wp-admin",
    "/wp-login.php",
    "/wp-json",
    "/wp-cron.php",
    "/xmlrpc.php",
    "/cart",
    "/checkout",
    "/my-account",
    "/wc-api",
    "/?wc-ajax",
    "/?add-to-cart",
    "/order-pay",
    "/order-received",
  ]

  # Payment gateway callbacks and the REST API must not be challenged.
  api_paths = ["/wp-json/", "/wc-api/"]

  # Stricter login throttling (requires a paid plan for period > 10 seconds).
  login_rate_limit_requests = 5
  login_rate_limit_period   = 60
  login_rate_limit_timeout  = 600

  # Bot Fight Mode cannot be skipped for webhooks, so keep it off for stores.
  bot_fight_mode = false

  # Security response headers (HSTS, nosniff, frame and referrer policy).
  # Check that every page still renders, including payment iframes, before enabling in production.
  enable_security_headers = true
}

output "security_headers_ruleset_id" {
  value = module.woocommerce_zone.security_headers_ruleset_id
}

output "cache_bypass_expression" {
  value = module.woocommerce_zone.cache_bypass_expression
}

output "zone_settings" {
  value = module.woocommerce_zone.zone_settings_applied
}
