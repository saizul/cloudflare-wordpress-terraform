# Plan-only tests that invalid inputs are rejected by variable validation
# before anything reaches the Cloudflare API.

mock_provider "cloudflare" {}

variables {
  zone_id = "0123456789abcdef0123456789abcdef"
}

run "accepts_valid_inputs" {
  command = plan

  variables {
    cache_bypass_paths   = ["/wp-admin", "/?wc-ajax", "/warenkorb"]
    cache_bypass_cookies = ["wordpress_logged_in_"]
    api_paths            = ["/wp-json/"]
    dns_records = {
      www = { name = "www", type = "A", content = "203.0.113.10", ttl = 300 }
      srv = { name = "_sip._tcp", type = "SRV", content = "0 5060 sip.example.com", priority = 10 }
    }
  }

  assert {
    condition     = length(cloudflare_dns_record.this) == 2
    error_message = "Valid inputs should plan cleanly."
  }
}

run "rejects_zone_id_uppercase" {
  command = plan

  variables {
    zone_id = "0123456789ABCDEF0123456789ABCDEF"
  }

  expect_failures = [var.zone_id]
}

run "rejects_zone_id_too_short" {
  command = plan

  variables {
    zone_id = "abc123"
  }

  expect_failures = [var.zone_id]
}

run "rejects_dns_unknown_type" {
  command = plan

  variables {
    dns_records = { x = { name = "@", type = "PTR", content = "example.com" } }
  }

  expect_failures = [var.dns_records]
}

run "rejects_dns_proxied_mx" {
  command = plan

  variables {
    dns_records = { mx = { name = "@", type = "MX", content = "mail.example.com", priority = 10, proxied = true } }
  }

  expect_failures = [var.dns_records]
}

run "rejects_dns_proxied_mail_host" {
  command = plan

  variables {
    dns_records = { mail = { name = "mail", type = "A", content = "203.0.113.20", proxied = true } }
  }

  expect_failures = [var.dns_records]
}

run "rejects_dns_proxied_with_ttl" {
  command = plan

  variables {
    dns_records = { www = { name = "www", type = "A", content = "203.0.113.10", proxied = true, ttl = 300 } }
  }

  expect_failures = [var.dns_records]
}

run "rejects_dns_ttl_out_of_range" {
  command = plan

  variables {
    dns_records = { www = { name = "www", type = "A", content = "203.0.113.10", ttl = 30 } }
  }

  expect_failures = [var.dns_records]
}

run "rejects_dns_mx_without_priority" {
  command = plan

  variables {
    dns_records = { mx = { name = "@", type = "MX", content = "mail.example.com" } }
  }

  expect_failures = [var.dns_records]
}

run "rejects_ssl_mode_unknown" {
  command = plan

  variables {
    ssl_mode = "full_strict"
  }

  expect_failures = [var.ssl_mode]
}

run "rejects_min_tls_unknown" {
  command = plan

  variables {
    min_tls_version = "1.4"
  }

  expect_failures = [var.min_tls_version]
}

run "rejects_static_extension_with_dot" {
  command = plan

  variables {
    static_asset_extensions = [".css"]
  }

  expect_failures = [var.static_asset_extensions]
}

run "rejects_static_extensions_empty" {
  command = plan

  variables {
    static_asset_extensions = []
  }

  expect_failures = [var.static_asset_extensions]
}

run "rejects_static_edge_ttl_too_low" {
  command = plan

  variables {
    static_edge_ttl = 30
  }

  expect_failures = [var.static_edge_ttl]
}

run "rejects_static_browser_ttl_too_high" {
  command = plan

  variables {
    static_browser_ttl = 31536001
  }

  expect_failures = [var.static_browser_ttl]
}

run "rejects_bypass_path_without_slash" {
  command = plan

  variables {
    cache_bypass_paths = ["wp-admin"]
  }

  expect_failures = [var.cache_bypass_paths]
}

run "rejects_bypass_path_with_quote" {
  command = plan

  variables {
    cache_bypass_paths = ["/cart\") or (true"]
  }

  expect_failures = [var.cache_bypass_paths]
}

run "rejects_bypass_path_with_space" {
  command = plan

  variables {
    cache_bypass_paths = ["/my account"]
  }

  expect_failures = [var.cache_bypass_paths]
}

run "rejects_bypass_bare_query_marker" {
  command = plan

  variables {
    cache_bypass_paths = ["/?"]
  }

  expect_failures = [var.cache_bypass_paths]
}

run "rejects_bypass_cookies_empty" {
  command = plan

  variables {
    cache_bypass_cookies = []
  }

  expect_failures = [var.cache_bypass_cookies]
}

run "rejects_bypass_cookie_with_quote" {
  command = plan

  variables {
    cache_bypass_cookies = ["wordpress_\""]
  }

  expect_failures = [var.cache_bypass_cookies]
}

run "rejects_bypass_cookie_with_equals" {
  command = plan

  variables {
    cache_bypass_cookies = ["session=1"]
  }

  expect_failures = [var.cache_bypass_cookies]
}

run "rejects_bad_bot_with_backslash" {
  command = plan

  variables {
    bad_bot_user_agents = ["bot\\"]
  }

  expect_failures = [var.bad_bot_user_agents]
}

run "rejects_bad_bot_empty_entry" {
  command = plan

  variables {
    bad_bot_user_agents = [""]
  }

  expect_failures = [var.bad_bot_user_agents]
}

run "rejects_rate_limit_requests_zero" {
  command = plan

  variables {
    login_rate_limit_requests = 0
  }

  expect_failures = [var.login_rate_limit_requests]
}

run "rejects_rate_limit_period_unsupported" {
  command = plan

  variables {
    login_rate_limit_period = 30
  }

  expect_failures = [var.login_rate_limit_period]
}

run "rejects_rate_limit_timeout_too_low" {
  command = plan

  variables {
    login_rate_limit_timeout = 5
  }

  expect_failures = [var.login_rate_limit_timeout]
}

run "rejects_api_path_without_slash" {
  command = plan

  variables {
    api_paths = ["wp-json/"]
  }

  expect_failures = [var.api_paths]
}

run "rejects_api_path_with_quote" {
  command = plan

  variables {
    api_paths = ["/wp-json/\""]
  }

  expect_failures = [var.api_paths]
}
