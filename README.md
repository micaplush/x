# x

This is my personal monorepo containing most of what I've built recently. It's
pretty much all integrated with Nix and I'm working on a blog post series to
document at least the most interesting stuff. You can find the introductory post
here:
[My Nix-based homelab monorepo](https://mica.lgbt/posts/2025/infrastructure-review/).

You're free to use this however you like but I don't think you'll be able to
just clone the repo and get anything running in here. This repo is probably best
used as inspiration or for spinning individual components out into their own
projects. If you do anything with it, I'd love to hear about it. 😊

## Naming

Cool people and total lunatics name their stuff "x" so ofc I had to follow suit.

Also, I've been using `x.<whatever>` as a prefix for my options in Nix modules
before I settled on naming this repo "x".

## Directory structure

Just a rough overview (the blog posts should fill in the rest):

- **bootstrap:** Text templates related to bootstrapping VMs
- **clients:** Hosts managed using this repo
  - The name will make sense if I ever get to the blog post describing my dreams
    for deployment tooling
- **domainconfigs:** Configs of deployed LibVirt VMs (aka "domains" in
  LibVirt-jargon)
- **modules:** All kinds of modules using the Nix module system
  - **flake:** Flake modules using flake-parts
  - **global:** Globalmods (will make sense when I get to that blog post)
  - **globaldata:** Globalmods that only contain config
  - **nixos:** Plain old NixOS modules
    - **base:** Generic modules for all kinds of hosts
    - **bootstrap:** Modules to be temporarily used while bootstrapping VMs
    - **peripherals:** Modules to deal with stuff attached to computers on the
      network or devices attached to the network that aren't really
      participating in this monorepo
    - **server:** Generic modules for servers
      - If I ever integrate my laptop this abstraction will make sense...
    - **services:** Things that servers run
- **pkgs**: Custom packages
  - **grafana-ntfy:** Forwards Grafana alerts to ntfy.sh
  - **paperless-imap-consume:** Speeds up Paperless document ingestion over IMAP
  - **paperless-labelgen:** Renders and optionally prints labels for documents
    added to Paperless
  - **secrets-generator:** Automates agenix secrets
  - **subenv:** Mediocre sandboxing thing I've hacked together a long time ago
  - **tailscale-get-authkey:** Obtains an auth key via the Tailscale API for VM
    provisioning
- **recipes:** Scripts for some (not all) just recipes
- **secrets:** agenix secrets and auxiliary files

## Licensing

If a "LICENSE" file appears in a directory, that license applies to all files in
that directory and subdirectories (until the next LICENSE file).
