# ---------------------------------------------------------------------------
# Zone
# ---------------------------------------------------------------------------

variable "zone_id" {
  description = "ID of the existing Cloudflare zone (32 hex characters). The zone itself is not created by this module."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.zone_id))
    error_message = "zone_id must be a 32 character lowercase hexadecimal Cloudflare zone ID."
  }
}

# ---------------------------------------------------------------------------
# DNS
# ---------------------------------------------------------------------------

variable "dns_records" {
  description = <<-EOT
    DNS records to manage, keyed by a stable identifier of your choosing (the key
    becomes part of the Terraform address, so do not rename keys casually).

    - name: record name relative to the zone ("@" for the apex, "www", "mail", ...)
      or a fully qualified name.
    - type: A, AAAA, CNAME, MX, TXT, SRV, CAA or NS.
    - content: record value. For TXT records pass the raw text; do not add
      surrounding quotes.
    - proxied: only A, AAAA and CNAME can be proxied. MX, TXT, SRV, CAA and NS
      are always DNS-only. Hostnames that look like mail services (mail, smtp,
      imap, pop, pop3, webmail, autodiscover, autoconfig) are refused when proxied
      because proxying them breaks email.
    - ttl: 1 means "automatic". Proxied records must use 1.
    - priority: required for MX (and SRV).
    - comment: optional note stored in Cloudflare.
  EOT
  type = map(object({
    name     = string
    type     = string
    content  = string
    proxied  = optional(bool, false)
    ttl      = optional(number, 1)
    priority = optional(number)
    comment  = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for r in values(var.dns_records) : contains(["A", "AAAA", "CNAME", "MX", "TXT", "SRV", "CAA", "NS"], r.type)
    ])
    error_message = "Each DNS record type must be one of A, AAAA, CNAME, MX, TXT, SRV, CAA, NS."
  }

  validation {
    condition = alltrue([
      for r in values(var.dns_records) : !r.proxied || contains(["A", "AAAA", "CNAME"], r.type)
    ])
    error_message = "Only A, AAAA and CNAME records can be proxied. MX and TXT (SPF, DKIM, DMARC) records must stay DNS-only."
  }

  validation {
    condition = alltrue([
      for r in values(var.dns_records) :
      !r.proxied || !can(regex("^(mail|smtp|imap|pop|pop3|webmail|autodiscover|autoconfig)(\\.|$)", lower(r.name)))
    ])
    error_message = "Mail-related hostnames (mail, smtp, imap, pop, pop3, webmail, autodiscover, autoconfig) must not be proxied; set proxied = false."
  }

  validation {
    condition = alltrue([
      for r in values(var.dns_records) : !r.proxied || r.ttl == 1
    ])
    error_message = "Proxied records must use ttl = 1 (automatic)."
  }

  validation {
    condition = alltrue([
      for r in values(var.dns_records) : r.ttl == 1 || (r.ttl >= 60 && r.ttl <= 86400)
    ])
    error_message = "ttl must be 1 (automatic) or between 60 and 86400 seconds."
  }

  validation {
    condition = alltrue([
      for r in values(var.dns_records) : !contains(["MX", "SRV"], r.type) || r.priority != null
    ])
    error_message = "MX and SRV records require a priority."
  }

  validation {
    condition = alltrue([
      for r in values(var.dns_records) : r.type != "TXT" || length(r.content) <= 2048
    ])
    error_message = "TXT record content must not exceed 2048 characters."
  }
}

# ---------------------------------------------------------------------------
# Zone settings
# ---------------------------------------------------------------------------

variable "manage_zone_settings" {
  description = "Manage the zone-level settings (SSL mode, Always Use HTTPS, minimum TLS, HTTP/3, Brotli). Set to false to leave all of them untouched."
  type        = bool
  default     = true
}

variable "ssl_mode" {
  description = "SSL/TLS encryption mode. Use \"strict\" (Full strict) once the origin has a valid certificate; \"full\" accepts self-signed origin certificates."
  type        = string
  default     = "strict"

  validation {
    condition     = contains(["off", "flexible", "full", "strict"], var.ssl_mode)
    error_message = "ssl_mode must be one of: off, flexible, full, strict."
  }
}

variable "always_use_https" {
  description = "Redirect all HTTP requests to HTTPS."
  type        = bool
  default     = true
}

variable "min_tls_version" {
  description = "Minimum TLS version accepted from visitors."
  type        = string
  default     = "1.2"

  validation {
    condition     = contains(["1.0", "1.1", "1.2", "1.3"], var.min_tls_version)
    error_message = "min_tls_version must be one of: 1.0, 1.1, 1.2, 1.3."
  }
}

variable "enable_http3" {
  description = "Enable HTTP/3 (QUIC) for visitors."
  type        = bool
  default     = true
}

variable "enable_brotli" {
  description = "Enable Brotli compression at the edge."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Cache rules
# ---------------------------------------------------------------------------

variable "enable_cache_rules" {
  description = "Create the zone cache ruleset (bypass for dynamic WordPress/WooCommerce traffic, cache for static assets). Note: this manages the whole http_request_cache_settings entrypoint ruleset of the zone."
  type        = bool
  default     = true
}

variable "static_asset_extensions" {
  description = "File extensions (without dot) treated as static assets and cached at the edge."
  type        = list(string)
  default = [
    "css", "js", "mjs", "map",
    "jpg", "jpeg", "png", "gif", "webp", "avif", "svg", "ico",
    "woff", "woff2", "ttf", "otf", "eot",
    "mp4", "webm", "mp3", "ogg", "pdf", "zip"
  ]

  validation {
    condition     = length(var.static_asset_extensions) > 0 && alltrue([for e in var.static_asset_extensions : can(regex("^[a-z0-9]+$", e))])
    error_message = "static_asset_extensions must be a non-empty list of lowercase alphanumeric extensions without a leading dot."
  }
}

variable "static_edge_ttl" {
  description = "Edge cache TTL in seconds for static assets."
  type        = number
  default     = 2592000 # 30 days

  validation {
    condition     = var.static_edge_ttl >= 60 && var.static_edge_ttl <= 31536000
    error_message = "static_edge_ttl must be between 60 and 31536000 seconds."
  }
}

variable "static_browser_ttl" {
  description = "Browser cache TTL in seconds for static assets."
  type        = number
  default     = 604800 # 7 days

  validation {
    condition     = var.static_browser_ttl >= 0 && var.static_browser_ttl <= 31536000
    error_message = "static_browser_ttl must be between 0 and 31536000 seconds."
  }
}

variable "cache_bypass_paths" {
  description = "URI path prefixes that are never cached. Add translated WooCommerce slugs here if your cart/checkout/account pages are not in English."
  type        = list(string)
  default = [
    "/wp-admin",
    "/wp-login.php",
    "/wp-json",
    "/wp-cron.php",
    "/xmlrpc.php",
    "/cart",
    "/checkout",
    "/my-account",
    "/wc-api",
    "/?wc-ajax"
  ]

  validation {
    condition     = alltrue([for p in var.cache_bypass_paths : startswith(p, "/")])
    error_message = "Every entry in cache_bypass_paths must start with \"/\"."
  }

  validation {
    condition     = alltrue([for p in var.cache_bypass_paths : !can(regex("[\"\\\\\\s]", p)) && p != "/?"])
    error_message = "cache_bypass_paths entries must not contain double quotes, backslashes or whitespace, and \"/?\" needs a query fragment after it (for example \"/?wc-ajax\")."
  }
}

variable "cache_bypass_cookies" {
  description = "Cookie name fragments. Any request whose Cookie header contains one of these bypasses the cache (logged-in users, WooCommerce carts, password-protected posts, commenters)."
  type        = list(string)
  default = [
    "wordpress_logged_in_",
    "wordpress_sec_",
    "wp-postpass_",
    "comment_author_",
    "woocommerce_items_in_cart",
    "woocommerce_cart_hash",
    "wp_woocommerce_session_"
  ]

  validation {
    condition     = length(var.cache_bypass_cookies) > 0
    error_message = "cache_bypass_cookies must contain at least one cookie fragment, otherwise logged-in users may receive cached pages."
  }

  validation {
    condition     = alltrue([for c in var.cache_bypass_cookies : length(c) > 0 && !can(regex("[\"\\\\;=\\s]", c))])
    error_message = "cache_bypass_cookies entries must be non-empty and must not contain double quotes, backslashes, semicolons, equals signs or whitespace."
  }
}

# ---------------------------------------------------------------------------
# WAF / security
# ---------------------------------------------------------------------------

variable "enable_waf_rules" {
  description = "Create the WAF custom rules ruleset. Note: this manages the whole http_request_firewall_custom entrypoint ruleset of the zone."
  type        = bool
  default     = true
}

variable "block_xmlrpc" {
  description = "Block all requests to /xmlrpc.php. Disable if you rely on Jetpack or the WordPress mobile app."
  type        = bool
  default     = true
}

variable "challenge_bad_bots" {
  description = "Managed-challenge requests whose User-Agent matches bad_bot_user_agents."
  type        = bool
  default     = true
}

variable "bad_bot_user_agents" {
  description = "Case-insensitive User-Agent fragments of scanners and scrapers to challenge."
  type        = list(string)
  default = [
    "sqlmap", "nikto", "nmap", "masscan", "acunetix", "wpscan",
    "dirbuster", "gobuster", "havij", "python-requests", "go-http-client",
    "libwww-perl", "zgrab", "semrushbot", "ahrefsbot", "mj12bot", "dotbot"
  ]

  validation {
    condition     = alltrue([for u in var.bad_bot_user_agents : length(u) > 0 && !can(regex("[\"\\\\]", u))])
    error_message = "bad_bot_user_agents entries must be non-empty and must not contain double quotes or backslashes."
  }
}

variable "enable_login_rate_limit" {
  description = "Rate-limit POST requests to /wp-login.php. Requires the http_ratelimit phase, which is available on all plans with plan-specific limits."
  type        = bool
  default     = true
}

variable "login_rate_limit_requests" {
  description = "Allowed login requests per period and client IP before blocking."
  type        = number
  default     = 5

  validation {
    condition     = var.login_rate_limit_requests >= 1 && var.login_rate_limit_requests <= 1000
    error_message = "login_rate_limit_requests must be between 1 and 1000."
  }
}

variable "login_rate_limit_period" {
  description = "Counting period in seconds. Free plans support only 10; paid plans also allow 60, 120, 300, 600 and 3600."
  type        = number
  default     = 10

  validation {
    condition     = contains([10, 60, 120, 300, 600, 3600], var.login_rate_limit_period)
    error_message = "login_rate_limit_period must be one of: 10, 60, 120, 300, 600, 3600."
  }
}

variable "login_rate_limit_timeout" {
  description = "How long, in seconds, a client stays blocked after exceeding the limit. Free plans support only 10; paid plans allow 10, 60, 600, 3600, 86400 and more."
  type        = number
  default     = 10

  validation {
    condition     = var.login_rate_limit_timeout >= 10 && var.login_rate_limit_timeout <= 86400
    error_message = "login_rate_limit_timeout must be between 10 and 86400 seconds."
  }
}

variable "skip_checks_on_api_paths" {
  description = "Create a rule that skips Browser Integrity Check, User Agent Blocking and Security Level on API paths (api_paths) so REST clients, payment webhooks and mobile apps are not challenged."
  type        = bool
  default     = true
}

variable "api_paths" {
  description = "URI path prefixes treated as machine-to-machine API traffic."
  type        = list(string)
  default     = ["/wp-json/", "/wc-api/"]

  validation {
    condition     = alltrue([for p in var.api_paths : startswith(p, "/")])
    error_message = "Every entry in api_paths must start with \"/\"."
  }

  validation {
    condition     = alltrue([for p in var.api_paths : !can(regex("[\"\\\\\\s]", p))])
    error_message = "api_paths entries must not contain double quotes, backslashes or whitespace."
  }
}

variable "bot_fight_mode" {
  description = "Set true/false to manage the zone's Bot Fight Mode through this module; null (default) leaves it untouched. Bot Fight Mode cannot be skipped by custom rules, so turn it off if it blocks payment webhooks or API clients."
  type        = bool
  default     = null
}

# ---------------------------------------------------------------------------
# Security response headers
# ---------------------------------------------------------------------------

variable "enable_security_headers" {
  description = "Create a response header transform ruleset that sets the headers in security_headers on every matching response. Off by default because it changes what browsers receive. Note: this manages the whole http_response_headers_transform entrypoint ruleset of the zone."
  type        = bool
  default     = false
}

variable "security_headers" {
  description = "Response headers to set (header name => value) when enable_security_headers is true. Values replace any header of the same name sent by the origin. The default HSTS value has no includeSubDomains or preload; extend it only when every subdomain serves HTTPS."
  type        = map(string)
  default = {
    "Strict-Transport-Security" = "max-age=31536000"
    "X-Content-Type-Options"    = "nosniff"
    "X-Frame-Options"           = "SAMEORIGIN"
    "Referrer-Policy"           = "strict-origin-when-cross-origin"
    "Permissions-Policy"        = "camera=(), microphone=(), geolocation=()"
  }

  validation {
    condition     = alltrue([for name in keys(var.security_headers) : can(regex("^[A-Za-z0-9][A-Za-z0-9-]*$", name))])
    error_message = "security_headers names must contain only letters, digits and hyphens, and must not start with a hyphen."
  }

  validation {
    condition     = alltrue([for value in values(var.security_headers) : length(trimspace(value)) > 0])
    error_message = "security_headers values must not be empty."
  }

  validation {
    condition = alltrue([
      for name in keys(var.security_headers) :
      !contains(["set-cookie", "content-length", "content-type", "transfer-encoding", "connection", "host", "location"], lower(name))
    ])
    error_message = "security_headers must not set hop-by-hop or content headers (Set-Cookie, Content-Length, Content-Type, Transfer-Encoding, Connection, Host, Location)."
  }
}

variable "security_headers_expression" {
  description = "Rule expression selecting the responses that receive security_headers. The default \"true\" matches every response of the zone."
  type        = string
  default     = "true"

  validation {
    condition     = length(trimspace(var.security_headers_expression)) > 0
    error_message = "security_headers_expression must not be empty; use \"true\" to match every response."
  }
}
