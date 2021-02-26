import Config

config :amgr, AmgrWeb.Endpoint,
  server: true,
  http: [port: {:system, "PORT"}],
  url: [host: "amgr.dev", port: 443],
  asset_url: "https://allanmacgregor.com"
  check_origin: ["https://amgr.dev", "//amgr.dev", "//allanmacgregor.com"]