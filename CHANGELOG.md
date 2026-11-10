# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

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
