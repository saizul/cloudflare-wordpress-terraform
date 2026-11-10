locals {
  api_path_expression = join(" or ", [for p in var.api_paths : "starts_with(http.request.uri.path, \"${p}\")"])

  bad_bot_expression = join(" or ", [for u in var.bad_bot_user_agents : "lower(http.user_agent) contains \"${lower(u)}\""])

  # Custom rules run in order; the API skip rule comes first. Each entry is
  # switched on or off by its "on" flag, then filtered into custom_rules.
  candidate_rules = [
    {
      on = var.skip_checks_on_api_paths && length(var.api_paths) > 0
      rule = {
        ref         = "wp_skip_api_checks"
        description = "Skip BIC, UA blocking and security level for API paths"
        action      = "skip"
        enabled     = true
        expression  = local.api_path_expression
        action_parameters = {
          products = ["bic", "uaBlock", "securityLevel"]
        }
      }
    },
    {
      on = var.block_xmlrpc
      rule = {
        ref         = "wp_block_xmlrpc"
        description = "Block xmlrpc.php"
        action      = "block"
        enabled     = true
        expression  = "(http.request.uri.path eq \"/xmlrpc.php\")"
        action_parameters = {
          products = null
        }
      }
    },
    {
      on = var.challenge_bad_bots && length(var.bad_bot_user_agents) > 0
      rule = {
        ref         = "wp_challenge_bad_bots"
        description = "Managed challenge for known scanner/scraper user agents"
        action      = "managed_challenge"
        enabled     = true
        expression  = local.bad_bot_expression
        action_parameters = {
          products = null
        }
      }
    },
  ]

  custom_rules = [for c in local.candidate_rules : c.rule if c.on]
}

resource "cloudflare_ruleset" "waf_custom" {
  count = var.enable_waf_rules && length(local.custom_rules) > 0 ? 1 : 0

  zone_id     = var.zone_id
  name        = "WordPress WAF custom rules"
  description = "Managed by Terraform: xmlrpc block, bad bot challenge, API skip."
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules = local.custom_rules
}

resource "cloudflare_ruleset" "login_rate_limit" {
  count = var.enable_waf_rules && var.enable_login_rate_limit ? 1 : 0

  zone_id     = var.zone_id
  name        = "WordPress login rate limit"
  description = "Managed by Terraform: throttle POST /wp-login.php per client IP."
  kind        = "zone"
  phase       = "http_ratelimit"

  rules = [
    {
      ref         = "wp_rate_limit_login"
      description = "Rate limit wp-login.php POST requests"
      action      = "block"
      enabled     = true
      expression  = "(http.request.uri.path eq \"/wp-login.php\" and http.request.method eq \"POST\")"
      ratelimit = {
        characteristics     = ["cf.colo.id", "ip.src"]
        period              = var.login_rate_limit_period
        requests_per_period = var.login_rate_limit_requests
        mitigation_timeout  = var.login_rate_limit_timeout
      }
    }
  ]
}
