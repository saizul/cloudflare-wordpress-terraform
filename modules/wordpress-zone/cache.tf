locals {
  # Build expression fragments. Cloudflare rule expressions use double quotes.
  bypass_path_exprs = [
    for p in var.cache_bypass_paths :
    startswith(p, "/?") ? "http.request.uri.query contains \"${substr(p, 2, -1)}\"" : "starts_with(http.request.uri.path, \"${p}\")"
  ]

  bypass_cookie_exprs = [
    for c in var.cache_bypass_cookies : "http.cookie contains \"${c}\""
  ]

  cache_bypass_expression = join(" or ", concat(local.bypass_path_exprs, local.bypass_cookie_exprs))

  static_extensions_set = join(" ", [for e in var.static_asset_extensions : "\"${e}\""])

  # Static assets are cached unless they are served from an area that must never be cached.
  cache_static_expression = "(http.request.uri.path.extension in {${local.static_extensions_set}}) and not starts_with(http.request.uri.path, \"/wp-json\")"
}

# Cache rules are evaluated in order and, when several rules set the same
# option, the LAST matching rule wins. Static assets are therefore listed last
# so that images/CSS/JS are still cached for logged-in users, while dynamic
# paths and cookie-carrying requests fall through to "bypass".
resource "cloudflare_ruleset" "cache" {
  count = var.enable_cache_rules ? 1 : 0

  zone_id     = var.zone_id
  name        = "WordPress cache rules"
  description = "Managed by Terraform: bypass dynamic WordPress/WooCommerce traffic, cache static assets."
  kind        = "zone"
  phase       = "http_request_cache_settings"

  rules = [
    {
      ref         = "wp_bypass_dynamic"
      description = "Bypass cache: wp-admin, login, REST API, cart, checkout, account and session cookies"
      action      = "set_cache_settings"
      enabled     = true
      expression  = local.cache_bypass_expression
      action_parameters = {
        cache = false
      }
    },
    {
      ref         = "wp_cache_static"
      description = "Cache static assets at the edge"
      action      = "set_cache_settings"
      enabled     = true
      expression  = local.cache_static_expression
      action_parameters = {
        cache = true
        edge_ttl = {
          mode    = "override_origin"
          default = var.static_edge_ttl
        }
        browser_ttl = {
          mode    = "override_origin"
          default = var.static_browser_ttl
        }
      }
    }
  ]
}
