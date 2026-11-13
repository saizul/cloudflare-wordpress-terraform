# Plan-only tests for the optional security response headers ruleset.

mock_provider "cloudflare" {}

variables {
  zone_id = "0123456789abcdef0123456789abcdef"
}

run "disabled_by_default" {
  command = plan

  assert {
    condition     = length(cloudflare_ruleset.security_headers) == 0 && output.security_headers_ruleset_id == null
    error_message = "Security headers must not be managed unless enabled."
  }
}

run "default_headers" {
  command = plan

  variables {
    enable_security_headers = true
  }

  assert {
    condition     = length(cloudflare_ruleset.security_headers) == 1
    error_message = "Enabling security headers should create one ruleset."
  }

  assert {
    condition     = cloudflare_ruleset.security_headers[0].phase == "http_response_headers_transform"
    error_message = "Security headers must use the http_response_headers_transform phase."
  }

  assert {
    condition     = cloudflare_ruleset.security_headers[0].rules[0].action == "rewrite" && cloudflare_ruleset.security_headers[0].rules[0].expression == "true"
    error_message = "Default rule should rewrite headers on every response."
  }

  assert {
    condition     = length(cloudflare_ruleset.security_headers[0].rules[0].action_parameters.headers) == 5
    error_message = "Five default security headers expected."
  }

  assert {
    condition     = cloudflare_ruleset.security_headers[0].rules[0].action_parameters.headers["Strict-Transport-Security"].value == "max-age=31536000"
    error_message = "Default HSTS must not include subdomains or preload."
  }

  assert {
    condition     = alltrue([for h in values(cloudflare_ruleset.security_headers[0].rules[0].action_parameters.headers) : h.operation == "set"])
    error_message = "Every header should use the set operation."
  }
}

run "custom_headers_and_expression" {
  command = plan

  variables {
    enable_security_headers     = true
    security_headers_expression = "not starts_with(http.request.uri.path, \"/wp-admin\")"
    security_headers = {
      "Content-Security-Policy" = "frame-ancestors 'self'"
    }
  }

  assert {
    condition     = keys(cloudflare_ruleset.security_headers[0].rules[0].action_parameters.headers) == tolist(["Content-Security-Policy"])
    error_message = "Custom headers should replace the defaults."
  }

  assert {
    condition     = cloudflare_ruleset.security_headers[0].rules[0].expression == "not starts_with(http.request.uri.path, \"/wp-admin\")"
    error_message = "Custom expression should be used."
  }
}

run "empty_header_map_creates_nothing" {
  command = plan

  variables {
    enable_security_headers = true
    security_headers        = {}
  }

  assert {
    condition     = length(cloudflare_ruleset.security_headers) == 0
    error_message = "An empty header map must not create an empty ruleset."
  }
}

run "rejects_invalid_header_name" {
  command = plan

  variables {
    enable_security_headers = true
    security_headers        = { "X Frame Options" = "DENY" }
  }

  expect_failures = [var.security_headers]
}

run "rejects_empty_header_value" {
  command = plan

  variables {
    enable_security_headers = true
    security_headers        = { "X-Frame-Options" = " " }
  }

  expect_failures = [var.security_headers]
}

run "rejects_reserved_header" {
  command = plan

  variables {
    enable_security_headers = true
    security_headers        = { "Set-Cookie" = "a=b" }
  }

  expect_failures = [var.security_headers]
}

run "rejects_empty_expression" {
  command = plan

  variables {
    security_headers_expression = ""
  }

  expect_failures = [var.security_headers_expression]
}
