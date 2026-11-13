# Plan-only tests of the module defaults. The mock provider never contacts the
# Cloudflare API, so no credentials are needed.

mock_provider "cloudflare" {}

variables {
  zone_id = "0123456789abcdef0123456789abcdef"
}

run "default_resources" {
  command = plan

  assert {
    condition     = length(cloudflare_zone_setting.this) == 5
    error_message = "Expected five managed zone settings by default."
  }

  assert {
    condition     = length(cloudflare_ruleset.cache) == 1
    error_message = "Cache ruleset should be created by default."
  }

  assert {
    condition     = length(cloudflare_ruleset.waf_custom) == 1
    error_message = "WAF custom ruleset should be created by default."
  }

  assert {
    condition     = length(cloudflare_ruleset.login_rate_limit) == 1
    error_message = "Login rate limit ruleset should be created by default."
  }

  assert {
    condition     = length(cloudflare_ruleset.security_headers) == 0
    error_message = "Security headers must be opt-in."
  }

  assert {
    condition     = length(cloudflare_bot_management.this) == 0
    error_message = "Bot Fight Mode must stay unmanaged when bot_fight_mode is null."
  }

  assert {
    condition     = length(cloudflare_dns_record.this) == 0
    error_message = "No DNS records should be planned without dns_records."
  }
}

run "default_zone_settings" {
  command = plan

  assert {
    condition     = cloudflare_zone_setting.this["ssl"].value == "strict"
    error_message = "SSL mode should default to strict."
  }

  assert {
    condition     = cloudflare_zone_setting.this["always_use_https"].value == "on"
    error_message = "Always Use HTTPS should default to on."
  }

  assert {
    condition     = cloudflare_zone_setting.this["min_tls_version"].value == "1.2"
    error_message = "Minimum TLS should default to 1.2."
  }

  assert {
    condition     = output.zone_settings_applied == tomap({ ssl = "strict", always_use_https = "on", min_tls_version = "1.2", http3 = "on", brotli = "on" })
    error_message = "zone_settings_applied output does not match the defaults."
  }
}

run "default_cache_rules" {
  command = plan

  assert {
    condition     = cloudflare_ruleset.cache[0].phase == "http_request_cache_settings"
    error_message = "Cache ruleset must use the http_request_cache_settings phase."
  }

  assert {
    condition     = [for r in cloudflare_ruleset.cache[0].rules : r.ref] == ["wp_bypass_dynamic", "wp_cache_static"]
    error_message = "Bypass rule must come before the static rule so static assets win."
  }

  assert {
    condition     = cloudflare_ruleset.cache[0].rules[0].action_parameters.cache == false
    error_message = "First cache rule must bypass the cache."
  }

  assert {
    condition     = strcontains(output.cache_bypass_expression, "starts_with(http.request.uri.path, \"/wp-admin\")")
    error_message = "Bypass expression should cover /wp-admin."
  }

  assert {
    condition     = strcontains(output.cache_bypass_expression, "http.request.uri.query contains \"wc-ajax\"")
    error_message = "A \"/?wc-ajax\" entry should become a query-string match."
  }

  assert {
    condition     = strcontains(output.cache_bypass_expression, "http.cookie contains \"wordpress_logged_in_\"")
    error_message = "Bypass expression should cover the logged-in cookie."
  }

  assert {
    condition     = cloudflare_ruleset.cache[0].rules[1].action_parameters.edge_ttl.default == 2592000
    error_message = "Static edge TTL should default to 30 days."
  }

  assert {
    condition     = cloudflare_ruleset.cache[0].rules[1].action_parameters.browser_ttl.default == 604800
    error_message = "Static browser TTL should default to 7 days."
  }
}

run "default_waf_rules" {
  command = plan

  assert {
    condition     = [for r in cloudflare_ruleset.waf_custom[0].rules : r.ref] == ["wp_skip_api_checks", "wp_block_xmlrpc", "wp_challenge_bad_bots"]
    error_message = "WAF rules should be API skip, xmlrpc block and bad bot challenge, in that order."
  }

  assert {
    condition     = cloudflare_ruleset.waf_custom[0].rules[1].action == "block"
    error_message = "xmlrpc rule must block."
  }

  assert {
    condition     = cloudflare_ruleset.login_rate_limit[0].rules[0].ratelimit.requests_per_period == 5 && cloudflare_ruleset.login_rate_limit[0].rules[0].ratelimit.period == 10
    error_message = "Login rate limit should default to 5 requests per 10 seconds."
  }
}
