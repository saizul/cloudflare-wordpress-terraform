locals {
  # Response header transform rules use the "rewrite" action with one entry per
  # header. "set" replaces any value sent by the origin (or a plugin), so the
  # edge always returns exactly the configured value.
  security_header_operations = {
    for name, value in var.security_headers : name => {
      operation = "set"
      value     = value
    }
  }
}

resource "cloudflare_ruleset" "security_headers" {
  count = var.enable_security_headers && length(var.security_headers) > 0 ? 1 : 0

  zone_id     = var.zone_id
  name        = "WordPress security headers"
  description = "Managed by Terraform: add security response headers."
  kind        = "zone"
  phase       = "http_response_headers_transform"

  rules = [
    {
      ref         = "wp_security_headers"
      description = "Set security response headers"
      action      = "rewrite"
      enabled     = true
      expression  = var.security_headers_expression
      action_parameters = {
        headers = local.security_header_operations
      }
    }
  ]
}
