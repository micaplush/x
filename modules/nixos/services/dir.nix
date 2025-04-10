{ config, globalConfig, pkgs, lib, ... }:

let
  cfg = config.x.services.dir;

  visibleServices = lib.pipe globalConfig.netsrv.services [
    (lib.filterAttrs (serviceName: service: service.publishDNS))
    lib.attrsToList
  ];

  hueStep = 360 / (builtins.length visibleServices);
  colors = lib.genList (i: "hsl(${builtins.toString (hueStep * i)}, var(--pill-saturation), var(--pill-lightness))") (builtins.length visibleServices);

  pill = name: portText: link: color:
    let
      inner = ''<span class="pill">
        <span class="name" style="background-color: ${color}">${name}</span><span class="port">${portText}</span>
      </span>'';

      outer =
        if link != null
        then ''<a href="${link}">${inner}</a>''
        else inner;
    in
    "<li>${outer}</li>";

  isHTTP = port: port.port == 80 && port.protocol == "tcp";
  isHTTPS = port: port.port == 443 && port.protocol == "tcp";

  regularPorts = lib.filterAttrs (portName: port: !((portName == "http" && isHTTP port) || (portName == "https" && isHTTPS port)));

  hasHTTP = service: service.ports ? "http" && isHTTP service.ports.http;
  hasHTTPS = service: service.ports ? "https" && isHTTPS service.ports.https;

  nonHTTPPortText = portName: port:
    if portName == "acme" && port.port == 80 && port.protocol == "tcp"
    then lib.toUpper portName
    else "${builtins.toString port.port}/${lib.toUpper port.protocol}";

  servicePills = serviceName: service: color: lib.concatLists [
    (lib.optional ((hasHTTP service) && !(hasHTTPS service)) (pill serviceName "HTTP" "http://${service.fqdn}" color))
    (lib.optional ((hasHTTPS service) && !(hasHTTP service)) (pill serviceName "HTTPS" "https://${service.fqdn}" color))
    (lib.optional ((hasHTTPS service) && (hasHTTP service)) (pill serviceName "HTTP/S" "https://${service.fqdn}" color))
    (lib.pipe service.ports [
      regularPorts
      (lib.mapAttrsToList (portName: port: pill serviceName (nonHTTPPortText portName port) null color))
    ])
  ];

  pillsList = lib.pipe visibleServices [
    (services: lib.concatLists [
      (builtins.filter ({ value, ... }: hasHTTP value || hasHTTPS value) services)
      (builtins.filter ({ value, ... }: !(hasHTTP value || hasHTTPS value)) services)
    ])
    (lib.zipListsWith (color: { name, value }: servicePills name value color) colors)
    lib.flatten
    (builtins.concatStringsSep "")
  ];

  index = builtins.toFile "index.html" ''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Service Directory</title>
      <style>
        body {
            --pill-lightness: 90%;
            --pill-saturation: 75%;

            font-family: sans-serif;
            font-size: 1.5em;
            list-style: none;
            margin: 2em auto 2em auto;
            max-width: 800px;
            text-align: center;
        }

        ul {
          display: flex;
          flex-direction: row;
          flex-wrap: wrap;
          justify-content: center;
          padding: 0;
        }

        li {
          display: inline-block;
          list-style: none;
        }

        a {
          text-decoration: none;
        }

        .pill {
          background: #eee;
          border-radius: 1em;
          border: 4px solid #eee;
          color: black;
          display: flex;
          margin: .2em;
          overflow: clip;
        }

        .pill .name {
          align-self: baseline;
          border-radius: 1em;
          display: inline-block;
          padding-bottom: .1em;
          padding-left: .5em;
          padding-right: .5em;
          padding-top: .1em;
        }

        .pill .port {
          align-self: baseline;
          display: inline-block;
          font-size: .85em;
          padding-bottom: .1em;
          padding-left: .35em;
          padding-right: .5em;
          padding-top: .1em;
        }
      </style>
    </head>
    <body>
      <h1>🏳️‍⚧️ Services 🏳️‍⚧️</h1>

      <ul>
        ${pillsList}
      </ul>
    </body>
    </html>
  '';

  root = pkgs.runCommandLocal "root" { } ''
    mkdir $out
    cp ${index} $out/index.html
  '';
in
{
  options.x.services.dir.enable = lib.mkEnableOption "the service directory page";

  config = lib.mkIf cfg.enable {
    x.server.caddy.services.dir.extraConfig = ''
      root * ${root}
      file_server
      header /* >Cache-Control no-store
    '';
  };
}

