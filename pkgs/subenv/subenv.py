#!/usr/bin/env python3

import click
import os
import subprocess

@click.command(add_help_option=False)
@click.option("--package", "-p", multiple=True, help="Add a package to the environment")
@click.option("--keep-env", "-E", multiple=True, help="Inherit an environment variable from the current environment")
@click.option("--set-env", "-e", nargs=2, multiple=True, help="Set an environment variable")
@click.option("--add-path", multiple=True, help="Add a string to $PATH")
@click.option("--bind", nargs=2, multiple=True, help="Bind mount a path into the sandbox")
@click.option("--ro-bind", nargs=2, multiple=True, help="Read-only bind mount a path into the sandbox")
@click.argument('cmd', nargs=-1)
@click.help_option("--help", "-h", help="Show this message and exit")
def subenv(package, keep_env, set_env, add_path, bind, ro_bind, cmd):
    """Like nix-shell but for running programs with bubblewrap"""

    nixBuild = ["nix-build", "<nixpkgs>", "--no-build-output", "--no-out-link"]
    for p in package:
        nixBuild.append("--attr")
        nixBuild.append(f"pkgs.{p}")
    storePaths = subprocess.check_output(nixBuild).split(b"\n")

    query = ["nix-store", "--query", "--requisites"]
    bwrap = ["--unshare-all", "--clearenv", "--setenv", "HOME", os.environ["HOME"]]
    bwrapPath = list(add_path)
    for p in storePaths:
        if p == b"":
            continue
        query.append(p)
        bp = os.path.join(p.decode("utf-8"), "bin")
        if os.path.isdir(bp):
            bwrapPath.append(bp)
    allStorePaths = subprocess.check_output(query).split(b"\n")
    for p in allStorePaths:
        if p == b"":
            continue
        bwrap.append("--ro-bind")
        bwrap.append(p)
        bwrap.append(p)
    bwrap.append("--setenv")
    bwrap.append("PATH")
    bwrap.append(":".join(bwrapPath))

    for k in keep_env:
        bwrap.append("--setenv")
        bwrap.append(k)
        bwrap.append(os.environ[k])
    for k, v in set_env:
        bwrap.append("--setenv")
        bwrap.append(k)
        bwrap.append(v)

    bwrapStorePath = subprocess.check_output(["nix-build", "<nixpkgs>", "--no-build-output", "--no-out-link", "--attr", "pkgs.bubblewrap"]).rstrip(b"\n")
    bwrap.insert(0, os.path.join(bwrapStorePath.decode("utf-8"), "bin", "bwrap"))

    for src, dst in bind:
        bwrap.append("--bind")
        bwrap.append(src)
        bwrap.append(dst)
    for src, dst in ro_bind:
        bwrap.append("--ro-bind")
        bwrap.append(src)
        bwrap.append(dst)

    for a in cmd:
        bwrap.append(a)

    os.execve(bwrap[0], argv=bwrap, env={})

if __name__ == "__main__":
    subenv()
