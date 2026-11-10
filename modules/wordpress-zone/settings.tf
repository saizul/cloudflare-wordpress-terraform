locals {
  zone_settings = var.manage_zone_settings ? {
    ssl              = var.ssl_mode
    always_use_https = var.always_use_https ? "on" : "off"
    min_tls_version  = var.min_tls_version
    http3            = var.enable_http3 ? "on" : "off"
    brotli           = var.enable_brotli ? "on" : "off"
  } : {}
}

resource "cloudflare_zone_setting" "this" {
  for_each = local.zone_settings

  zone_id    = var.zone_id
  setting_id = each.key
  value      = each.value
}

resource "cloudflare_bot_management" "this" {
  count = var.bot_fight_mode == null ? 0 : 1

  zone_id    = var.zone_id
  fight_mode = var.bot_fight_mode
}
