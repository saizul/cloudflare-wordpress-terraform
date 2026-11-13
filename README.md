# cloudflare-wordpress-terraform

[![CI](https://github.com/saizul/cloudflare-wordpress-terraform/actions/workflows/ci.yml/badge.svg)](https://github.com/saizul/cloudflare-wordpress-terraform/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A Terraform module that configures an existing Cloudflare zone for a WordPress or WooCommerce site: DNS (with email records kept safe), TLS settings, cache rules and WAF rules. It uses the official `cloudflare/cloudflare` provider **v5** (`>= 5.28, < 6.0`; developed against 5.28.1).

Maintained by [Saizul Amin](https://saizul.com).

## What it configures

| Area | Resource | Default behaviour |
| --- | --- | --- |
| DNS | `cloudflare_dns_record` | A/AAAA/CNAME can be proxied; MX/TXT/etc. are always DNS-only |
| TLS and transport | `cloudflare_zone_setting` | SSL `strict`, Always Use HTTPS on, min TLS 1.2, HTTP/3 on, Brotli on |
| Cache | `cloudflare_ruleset` (`http_request_cache_settings`) | bypass dynamic traffic, cache static assets |
| WAF | `cloudflare_ruleset` (`http_request_firewall_custom`) | block xmlrpc, challenge bad bots, skip checks on API paths |
| Rate limiting | `cloudflare_ruleset` (`http_ratelimit`) | throttle `POST /wp-login.php` |
| Security headers | `cloudflare_ruleset` (`http_response_headers_transform`) | off; opt in with `enable_security_headers` |
| Bot Fight Mode | `cloudflare_bot_management` | untouched unless `bot_fight_mode` is set |

The module does **not** create the zone, change nameservers, or manage Page Shield policies.

## Quick start

```hcl
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.28"
    }
  }
}

provider "cloudflare" {} # reads CLOUDFLARE_API_TOKEN

module "wordpress_zone" {
  source = "github.com/saizul/cloudflare-wordpress-terraform//modules/wordpress-zone?ref=v1.0.0"

  zone_id = var.zone_id

  dns_records = {
    apex = { name = "@", type = "A", content = "203.0.113.10", proxied = true }
    www  = { name = "www", type = "CNAME", content = "example.com", proxied = true }
    mx   = { name = "@", type = "MX", content = "mail.example.com", priority = 10 }
    spf  = { name = "@", type = "TXT", content = "v=spf1 mx -all" }
  }
}
```

Create an API token scoped to the single zone with the permissions your configuration needs: Zone Settings Edit, DNS Edit, Zone WAF Edit, Cache Rules Edit (cache rules), Transform Rules Edit (only if you enable security headers) and, only if you set `bot_fight_mode`, Bot Management Edit. Check the exact permission names in the Cloudflare dashboard when creating the token.

See [`examples/basic`](examples/basic) and [`examples/woocommerce`](examples/woocommerce).

## Rule reference

### Cache rules (`http_request_cache_settings`)

Rules are evaluated in order and, when two rules set the same option, **the last matching rule wins**. The module lists the bypass rule first and the static rule last, so static files stay cached even for logged-in users, while everything dynamic is not cached.

1. **`wp_bypass_dynamic`** sets `cache = false` when any of these match:
   - Path prefixes (`cache_bypass_paths`): `/wp-admin`, `/wp-login.php`, `/wp-json`, `/wp-cron.php`, `/xmlrpc.php`, `/cart`, `/checkout`, `/my-account`, `/wc-api`, and the query string `wc-ajax`. An entry that begins with `/?` is matched against the query string instead of the path.
   - Cookies (`cache_bypass_cookies`): `wordpress_logged_in_`, `wordpress_sec_`, `wp-postpass_`, `comment_author_`, `woocommerce_items_in_cart`, `woocommerce_cart_hash`, `wp_woocommerce_session_`.
2. **`wp_cache_static`** caches files whose extension is in `static_asset_extensions` (CSS, JS, images, fonts, media, PDF, ZIP) with an edge TTL of `static_edge_ttl` (30 days) and a browser TTL of `static_browser_ttl` (7 days), except under `/wp-json`.

HTML pages are intentionally not cached by Cloudflare here. Use a WordPress page cache plugin at the origin, or extend the ruleset yourself, if you want full-page edge caching.

The module owns the zone's whole `http_request_cache_settings` entrypoint ruleset. If you already have cache rules, import them or set `enable_cache_rules = false`.

### WAF custom rules (`http_request_firewall_custom`)

1. **`wp_skip_api_checks`** (`skip_checks_on_api_paths`): for `/wp-json/` and `/wc-api/` (`api_paths`), skips Browser Integrity Check, User Agent Blocking and Security Level so REST clients, mobile apps and payment webhooks are not challenged. It does not skip the WAF itself and cannot skip Bot Fight Mode (Cloudflare does not support that); this is why `bot_fight_mode` exists.
2. **`wp_block_xmlrpc`** (`block_xmlrpc`): blocks `http.request.uri.path eq "/xmlrpc.php"`. Turn it off if you use Jetpack or the WordPress mobile app's XML-RPC.
3. **`wp_challenge_bad_bots`** (`challenge_bad_bots`): managed challenge when the lowercased User-Agent contains an entry of `bad_bot_user_agents` (scanners such as sqlmap, nikto, wpscan, and aggressive SEO crawlers). The default list also includes generic HTTP client strings like `python-requests`; review it if you have legitimate integrations that call your site with such clients, or add them to `api_paths`.

### Rate limiting (`http_ratelimit`)

**`wp_rate_limit_login`**: blocks a client IP (per Cloudflare data centre) that sends more than `login_rate_limit_requests` `POST /wp-login.php` requests within `login_rate_limit_period` seconds, for `login_rate_limit_timeout` seconds. Defaults (5 requests / 10 s / 10 s) fit the Free plan. Longer periods and timeouts need a paid plan; check the current [Cloudflare rate limiting limits](https://developers.cloudflare.com/waf/rate-limiting-rules/) for your plan, because applying an unsupported value fails at the API.

### Security headers (`http_response_headers_transform`)

Off by default. With `enable_security_headers = true` the module adds **`wp_security_headers`**, a `rewrite` rule that sets every header in `security_headers` on responses matching `security_headers_expression` (default `true`, all responses). The `set` operation replaces any value sent by WordPress or a plugin, so remove a header from the map if a plugin should own it.

| Header | Default value |
| --- | --- |
| `Strict-Transport-Security` | `max-age=31536000` |
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `SAMEORIGIN` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` |

Passing your own map replaces the defaults entirely. HSTS is deliberately sent without `includeSubDomains` or `preload`: browsers remember it for the whole `max-age`, so add those only when every subdomain serves valid HTTPS. `X-Frame-Options: SAMEORIGIN` blocks other sites from framing your pages; payment gateways that frame *their* page inside yours are unaffected, but check embeds of your site elsewhere. Header names are validated (letters, digits, hyphens) and headers such as `Set-Cookie`, `Content-Type` or `Location` are refused.

To leave the admin area alone, for example:

```hcl
enable_security_headers     = true
security_headers_expression = "not starts_with(http.request.uri.path, \"/wp-admin\")"
```

Like the other rulesets, this one owns the zone's whole `http_response_headers_transform` entrypoint ruleset; import an existing one before enabling.

### Zone settings

| Variable | Setting | Default |
| --- | --- | --- |
| `ssl_mode` | SSL/TLS mode | `strict` (Full strict) |
| `always_use_https` | Always Use HTTPS | `true` |
| `min_tls_version` | Minimum TLS | `1.2` |
| `enable_http3` | HTTP/3 | `true` |
| `enable_brotli` | Brotli | `true` |

**Full (strict) requires a valid certificate on the origin** (Let's Encrypt or a Cloudflare Origin CA certificate). Switching to `strict` before the origin is ready results in 526 errors. Terraform cannot "destroy" a zone setting, so removing the module leaves the values in place.

## Email-records safety checklist

Moving DNS to Cloudflare is the riskiest moment for email. Work through this before changing nameservers or running `apply`:

1. Export the current zone from your existing DNS provider and keep a copy.
2. Copy every `MX`, `TXT` (SPF, DKIM, DMARC, verification), `SRV` and mail-host `A` record into `dns_records`. Compare counts against the export.
3. Keep all of them `proxied = false`. The module's validation rejects proxied MX/TXT records and proxied hosts named `mail`, `smtp`, `imap`, `pop`, `pop3`, `webmail`, `autodiscover` or `autoconfig`.
4. Keep the SPF record to **one** `v=spf1` TXT record per name; merge includes instead of adding a second record.
5. DKIM: copy the selector name and the full public key; long keys may be split across several quoted strings by other providers, so join them into one value.
6. DMARC: start with `p=none` (or your current policy) and a `rua=` mailbox you read.
7. Remember that the `A` record that `MX` targets (for example `mail.example.com`) must point to the mail server's real IP, not Cloudflare.
8. Run `terraform plan` and read the list of DNS records. Check the `dns_only_dns_records` output after apply: every mail record must appear in it.
9. Before switching nameservers, send test mail both ways and check headers for `spf=pass`, `dkim=pass`, `dmarc=pass`.
10. Lower TTLs at the old provider 24 hours before the switch, and keep the old zone available for a few days.

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `zone_id` | `string` | n/a (required) | Existing zone ID (32 hex characters) |
| `dns_records` | `map(object)` | `{}` | Records keyed by a stable identifier; validated |
| `manage_zone_settings` | `bool` | `true` | Manage the settings below |
| `ssl_mode` | `string` | `"strict"` | `off`, `flexible`, `full`, `strict` |
| `always_use_https` | `bool` | `true` | Redirect HTTP to HTTPS |
| `min_tls_version` | `string` | `"1.2"` | `1.0` to `1.3` |
| `enable_http3` | `bool` | `true` | HTTP/3 |
| `enable_brotli` | `bool` | `true` | Brotli |
| `enable_cache_rules` | `bool` | `true` | Manage cache ruleset |
| `static_asset_extensions` | `list(string)` | see `variables.tf` | Extensions to cache |
| `static_edge_ttl` | `number` | `2592000` | Edge TTL (seconds) |
| `static_browser_ttl` | `number` | `604800` | Browser TTL (seconds) |
| `cache_bypass_paths` | `list(string)` | see `variables.tf` | Never-cache paths |
| `cache_bypass_cookies` | `list(string)` | see `variables.tf` | Never-cache cookie fragments |
| `enable_waf_rules` | `bool` | `true` | Manage WAF and rate limit rulesets |
| `block_xmlrpc` | `bool` | `true` | Block `/xmlrpc.php` |
| `challenge_bad_bots` | `bool` | `true` | Challenge listed user agents |
| `bad_bot_user_agents` | `list(string)` | see `variables.tf` | UA fragments |
| `enable_login_rate_limit` | `bool` | `true` | Rate-limit `wp-login.php` |
| `login_rate_limit_requests` | `number` | `5` | Requests per period |
| `login_rate_limit_period` | `number` | `10` | Seconds: 10, 60, 120, 300, 600, 3600 |
| `login_rate_limit_timeout` | `number` | `10` | Block duration (seconds) |
| `skip_checks_on_api_paths` | `bool` | `true` | Skip BIC/UA/security level on API paths |
| `api_paths` | `list(string)` | `["/wp-json/", "/wc-api/"]` | API path prefixes |
| `bot_fight_mode` | `bool` | `null` | `null` leaves it unmanaged |
| `enable_security_headers` | `bool` | `false` | Manage the response header transform ruleset |
| `security_headers` | `map(string)` | see [Security headers](#security-headers-http_response_headers_transform) | Header name to value |
| `security_headers_expression` | `string` | `"true"` | Responses that receive the headers |

## Outputs

`dns_record_ids`, `proxied_dns_records`, `dns_only_dns_records`, `zone_settings_applied`, `cache_ruleset_id`, `waf_custom_ruleset_id`, `login_rate_limit_ruleset_id`, `security_headers_ruleset_id`, `cache_bypass_expression`.

## Upgrading from provider v4

v5 renamed resources: `cloudflare_record` became `cloudflare_dns_record` (`value` is now `content`, `ttl` is required), `cloudflare_zone_settings_override` became one `cloudflare_zone_setting` per setting, and `cloudflare_ruleset` rules are now an attribute list instead of repeated `rules` blocks. This module targets v5 only.

## Validation, tests and CI

Entries of `cache_bypass_paths`, `cache_bypass_cookies`, `api_paths` and `bad_bot_user_agents` are interpolated into rule expressions, so values containing double quotes or backslashes (and whitespace, for paths and cookies) are rejected rather than producing a broken or wider-than-intended expression.

The module ships native `terraform test` suites in [`modules/wordpress-zone/tests`](modules/wordpress-zone/tests). They use `mock_provider "cloudflare"` with `command = plan`, so they need no API token and create nothing:

- `defaults.tftest.hcl`: resources and rule order planned with default inputs.
- `toggles.tftest.hcl`: each feature flag adds or removes the expected rulesets, rules and settings; DNS proxy handling.
- `security_headers.tftest.hcl`: the optional header transform ruleset.
- `validation.tftest.hcl`: invalid inputs are rejected (`expect_failures`).

```sh
cd modules/wordpress-zone
terraform init -backend=false
terraform test
```

`terraform test` with mock providers needs Terraform 1.7 or later; the module itself still supports 1.6.

CI runs `terraform fmt -check -recursive`, `terraform init -backend=false` and `terraform validate` for the module and both examples, `terraform test` for the module, and `tflint` with the recommended Terraform ruleset. Note that `validate` and the tests check syntax, provider schema and module logic, not whether your Cloudflare plan supports a given rule; always review `terraform plan`.

## Importing existing resources

Cloudflare allows one entrypoint ruleset per phase and zone. If a ruleset already exists, import it before applying, for example:

```sh
terraform import 'module.wordpress_zone.cloudflare_ruleset.cache[0]' zones/<zone_id>/<ruleset_id>
```

## License

MIT, see [LICENSE](LICENSE).
