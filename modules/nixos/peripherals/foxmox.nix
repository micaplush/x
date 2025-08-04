{
  x.global.oidc.clients.foxmox = {
    settings = {
      client_name = "Foxmox";
      pkce_challenge_method = "S256";
      public = false;
      redirect_uris = [
        "https://fox01.in.tbx.at:8006"
        "https://fox02.in.tbx.at:8006"
        "https://fox03.in.tbx.at:8006"
      ];
      scopes = [
        "openid"
        "profile"
        "email"
        "groups"
      ];
      response_types = [ "code" ];
      grant_types = [ "authorization_code" ];
      require_pkce = true;
      token_endpoint_auth_method = "client_secret_basic";
      access_token_signed_response_alg = "none";
      userinfo_signed_response_alg = "none";
    };
  };

  x.global.email.accounts."foxmox@systems.tbx.at" = {
    permissions.send = true;
  };
}
