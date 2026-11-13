# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Optional security response headers via a `cloudflare_ruleset` in the `http_response_headers_transform` phase (`enable_security_headers`, `security_headers`, `security_headers_expression`), off by default, and the `security_headers_ruleset_id` output.
- Native `terraform test` suites under `modules/wordpress-zone/tests` using a mock Cloudflare provider: defaults, feature toggles, security headers and input validation.
- CI job running `terraform test` for the module.

### Changed
- `cache_bypass_paths`, `cache_bypass_cookies` and `api_paths` now reject double quotes, backslashes and whitespace (and cookies also `;` and `=`), which would otherwise break or widen the generated rule expressions. A bare `"/?"` bypass entry is rejected.
- `examples/woocommerce` enables the security headers.

## [1.0.0] - 2026-11-10

### Added
- `modules/wordpress-zone` module targeting `cloudflare/cloudflare` provider v5 (`>= 5.28, < 6.0`).
- DNS records via `cloudflare_dns_record` with validation that keeps MX/TXT (SPF, DKIM, DMARC) and mail hostnames DNS-only.
- Zone settings via `cloudflare_zone_setting`: SSL Full (strict), Always Use HTTPS, minimum TLS 1.2, HTTP/3, Brotli.
- Cache rules: bypass for wp-admin, wp-login, wp-json, cart, checkout, my-account and WordPress/WooCommerce cookies; edge caching for static assets.
- WAF custom rules: block `xmlrpc.php`, managed challenge for known bad bot user agents, skip of BIC/UA blocking/security level on API paths.
- Rate limiting rule for `POST /wp-login.php`.
- Optional management of Bot Fight Mode.
- `examples/basic` and `examples/woocommerce`.
- GitHub Actions: `terraform fmt -check`, `init -backend=false`, `validate` and `tflint`.
