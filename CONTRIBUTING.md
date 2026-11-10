# Contributing

Thanks for helping improve this module.

## Ground rules

- Use `example.com`, documentation IP ranges (`203.0.113.0/24`, `2001:db8::/32`) and fake IDs in examples and issues. Never commit tokens, zone IDs or real DKIM keys.
- Target the Cloudflare provider v5 resource names (`cloudflare_dns_record`, `cloudflare_zone_setting`, `cloudflare_ruleset`).
- Every new input needs a `description`, a `type` and, where a wrong value is possible, a `validation` block.
- Every new rule needs an entry in the README rule reference.

## Local checks

```sh
terraform fmt -recursive
for d in modules/wordpress-zone examples/basic examples/woocommerce; do
  (cd "$d" && terraform init -backend=false && terraform validate)
done
tflint --init && tflint --chdir=modules/wordpress-zone --config="$PWD/.tflint.hcl"
```

All of these run in CI and must pass.

## Pull requests

1. Fork and create a branch from `main`.
2. Keep changes focused and update `CHANGELOG.md` under `Unreleased`.
3. Describe how you verified the change (a `terraform plan` excerpt with redacted IDs is ideal).

## Reporting security issues

Please do not open a public issue for vulnerabilities in the rules themselves. Contact the maintainer through https://saizul.com.
