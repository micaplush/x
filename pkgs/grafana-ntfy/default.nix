{ self, ... }:

self.lib.buildGoModule {
  name = "grafana-ntfy";
  vendorHash = null;
}
