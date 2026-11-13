# Plan-only tests that each feature flag adds or removes the expected resources.

mock_provider "cloudflare" {}

variables {
  zone_id = "0123456789abcdef0123456789abcdef"
}

run "everything_disabled" {
  command = plan

  variables {
    manage_zone_settings = false
    enable_cache_rules   = false
    enable_waf_rules     = false
  }

  assert {
    condition     = length(cloudflare_zone_setting.this) == 0
    error_message = "No zone settings should be managed when manage_zone_settings is false."
  }

  assert {
    condition     = length(cloudflare_ruleset.cache) + length(cloudflare_ruleset.waf_custom) + length(cloudflare_ruleset.login_rate_limit) == 0
    error_message = "No rulesets should be created when cache and WAF rules are disabled."
  }

  assert {
    condition     = output.cache_ruleset_id == null && output.waf_custom_ruleset_id == null && output.login_rate_limit_ruleset_id == null
    error_message = "Ruleset ID outputs should be null when the rulesets are disabled."
  }
}

run "waf_flag_also_disables_rate_limit" {
  command = plan

  variables {
    enable_waf_rules        = false
    enable_login_rate_limit = true
  }

  assert {
    condition     = length(cloudflare_ruleset.login_rate_limit) == 0
    error_message = "enable_waf_rules = false must also skip the login rate limit."
  }
}

run "no_custom_rules_means_no_waf_ruleset" {
  command = plan

  variables {
    skip_checks_on_api_paths = false
    block_xmlrpc             = false
    challenge_bad_bots       = false
  }

  assert {
    condition     = length(cloudflare_ruleset.waf_custom) == 0
    error_message = "An empty WAF ruleset must not be created."
  }

  assert {
    condition     = length(cloudflare_ruleset.login_rate_limit) == 1
    error_message = "The login rate limit is independent of the custom rules."
  }
}

run "xmlrpc_allowed_for_jetpack" {
  command = plan

  variables {
    block_xmlrpc = false
  }

  assert {
    condition     = [for r in cloudflare_ruleset.waf_custom[0].rules : r.ref] == ["wp_skip_api_checks", "wp_challenge_bad_bots"]
    error_message = "Only the xmlrpc rule should be removed."
  }
}

run "empty_api_paths_drop_skip_rule" {
  command = plan

  variables {
    api_paths = []
  }

  assert {
    condition     = !contains([for r in cloudflare_ruleset.waf_custom[0].rules : r.ref], "wp_skip_api_checks")
    error_message = "The skip rule needs at least one API path."
  }
}

run "bad_bot_user_agents_are_lowercased" {
  command = plan

  variables {
    block_xmlrpc             = false
    skip_checks_on_api_paths = false
    bad_bot_user_agents      = ["SQLMap", "Nikto"]
  }

  assert {
    condition     = cloudflare_ruleset.waf_custom[0].rules[0].expression == "lower(http.user_agent) contains \"sqlmap\" or lower(http.user_agent) contains \"nikto\""
    error_message = "User agent fragments should be lowercased and joined with or."
  }
}

run "bot_fight_mode_managed" {
  command = plan

  variables {
    bot_fight_mode = false
  }

  assert {
    condition     = length(cloudflare_bot_management.this) == 1 && cloudflare_bot_management.this[0].fight_mode == false
    error_message = "Setting bot_fight_mode should manage Bot Fight Mode with that value."
  }
}

run "zone_setting_overrides" {
  command = plan

  variables {
    ssl_mode         = "full"
    always_use_https = false
    min_tls_version  = "1.3"
    enable_http3     = false
    enable_brotli    = false
  }

  assert {
    condition     = output.zone_settings_applied == tomap({ ssl = "full", always_use_https = "off", min_tls_version = "1.3", http3 = "off", brotli = "off" })
    error_message = "Zone setting variables should map to on/off values."
  }
}

run "dns_records_proxy_rules" {
  command = plan

  variables {
    dns_records = {
      apex = { name = "@", type = "A", content = "203.0.113.10", proxied = true }
      www  = { name = "www", type = "CNAME", content = "example.com", proxied = true }
      mail = { name = "mail", type = "A", content = "203.0.113.20" }
      mx   = { name = "@", type = "MX", content = "mail.example.com", priority = 10 }
      spf  = { name = "@", type = "TXT", content = "v=spf1 mx -all" }
    }
  }

  assert {
    condition     = length(cloudflare_dns_record.this) == 5
    error_message = "Every DNS record should be planned."
  }

  assert {
    condition     = cloudflare_dns_record.this["apex"].proxied && !cloudflare_dns_record.this["mx"].proxied && !cloudflare_dns_record.this["mail"].proxied
    error_message = "Web records should be proxied and mail records DNS-only."
  }

  assert {
    condition     = output.proxied_dns_records == tolist(["apex", "www"])
    error_message = "proxied_dns_records should list only the web records."
  }

  assert {
    condition     = output.dns_only_dns_records == tolist(["mail", "mx", "spf"])
    error_message = "dns_only_dns_records should list every mail record."
  }

  assert {
    condition     = cloudflare_dns_record.this["mx"].priority == 10
    error_message = "MX priority should be passed through."
  }
}

run "custom_static_ttls" {
  command = plan

  variables {
    static_edge_ttl         = 86400
    static_browser_ttl      = 0
    static_asset_extensions = ["css", "js"]
  }

  assert {
    condition     = cloudflare_ruleset.cache[0].rules[1].action_parameters.edge_ttl.default == 86400 && cloudflare_ruleset.cache[0].rules[1].action_parameters.browser_ttl.default == 0
    error_message = "Static TTL overrides should be applied."
  }

  assert {
    condition     = startswith(cloudflare_ruleset.cache[0].rules[1].expression, "(http.request.uri.path.extension in {\"css\" \"js\"})")
    error_message = "Static rule should list only the configured extensions."
  }
}
