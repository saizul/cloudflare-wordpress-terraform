locals {
  # Cloudflare returns "@" as the zone apex name; send it through unchanged.
  dns_records = var.dns_records
}

resource "cloudflare_dns_record" "this" {
  for_each = local.dns_records

  zone_id  = var.zone_id
  name     = each.value.name
  type     = each.value.type
  content  = each.value.content
  ttl      = each.value.ttl
  proxied  = contains(["A", "AAAA", "CNAME"], each.value.type) ? each.value.proxied : false
  priority = each.value.priority
  comment  = each.value.comment
}
