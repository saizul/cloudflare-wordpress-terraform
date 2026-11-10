output "dns_record_ids" {
  description = "Map of record key to Cloudflare DNS record ID."
  value       = { for k, r in cloudflare_dns_record.this : k => r.id }
}

output "proxied_dns_records" {
  description = "Keys of the DNS records that are proxied through Cloudflare."
  value       = sort([for k, r in cloudflare_dns_record.this : k if r.proxied])
}

output "dns_only_dns_records" {
  description = "Keys of the DNS records that are DNS-only (should include every mail record)."
  value       = sort([for k, r in cloudflare_dns_record.this : k if !r.proxied])
}

output "zone_settings_applied" {
  description = "Zone settings managed by this module and their configured values."
  value       = local.zone_settings
}

output "cache_ruleset_id" {
  description = "ID of the cache ruleset, or null when disabled."
  value       = try(cloudflare_ruleset.cache[0].id, null)
}

output "waf_custom_ruleset_id" {
  description = "ID of the WAF custom rules ruleset, or null when disabled."
  value       = try(cloudflare_ruleset.waf_custom[0].id, null)
}

output "login_rate_limit_ruleset_id" {
  description = "ID of the login rate limiting ruleset, or null when disabled."
  value       = try(cloudflare_ruleset.login_rate_limit[0].id, null)
}

output "cache_bypass_expression" {
  description = "The rendered cache-bypass expression, useful for reviewing before apply."
  value       = local.cache_bypass_expression
}
