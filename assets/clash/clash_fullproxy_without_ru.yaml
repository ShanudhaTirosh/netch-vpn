# Netch VPN — Clash/Mihomo profile: full proxy EXCEPT Russia (RU direct).
# install.sh substitutes ${DOMAIN} and ${SUB_PATH}. Selectable via -clash 2.
# Everything goes through the proxy by default; RU geosite/geoip + private
# nets stay direct. Fresh baseline — review before production.
mixed-port: 7890
allow-lan: false
mode: rule
log-level: info
ipv6: true
external-controller: 127.0.0.1:9090

dns:
  enable: true
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver: [https://1.1.1.1/dns-query, https://8.8.8.8/dns-query]

proxy-providers:
  netch:
    type: http
    # NOTE (verify before production): ${SUB_PATH} is the RAW subscription base.
    # mihomo/clash-meta can parse a base64 v2ray subscription from it. For a
    # clash-native feed instead, enable the panel Clash subscription
    # (subClashEnable=true + a wired subClashPath) and point this URL there.
    # Per-client feeds need the client's subId appended to the path.
    url: "https://${DOMAIN}/${SUB_PATH}"
    interval: 3600
    path: ./providers/netch.yaml
    health-check: { enable: true, url: https://www.gstatic.com/generate_204, interval: 300 }

proxy-groups:
  - { name: NETCH, type: select, use: [netch], proxies: [AUTO, DIRECT] }
  - { name: AUTO, type: url-test, use: [netch], url: https://www.gstatic.com/generate_204, interval: 300, tolerance: 50 }

rules:
  - GEOIP,private,DIRECT,no-resolve
  - GEOSITE,category-ads-all,REJECT
  - GEOSITE,ru,DIRECT
  - GEOIP,ru,DIRECT,no-resolve
  - MATCH,NETCH
