{ self, ... }:

self.lib.buildGoModule {
  name = "secrets-generator";
  vendorHash = "sha256-dnA3fxXOLF2jMo8yFZQ/03DtmPwuYTyvU31V6PSt/hg=";

  subPackages = [ "cmd/secrets-generator" ];
}
