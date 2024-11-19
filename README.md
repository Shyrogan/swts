# **S**hyrogan's **w**idgets **t**hat **s**ucks

## Getting started

Add this repository to your flake as an input.

```nix
{
  inputs.swts.url = "github:Shyrogan/swts"
}
```

Use one of the widget as a package
```
// Run with the `swts-desktop` command
environment.systemPackages = [ swts.${pkgs.sytem}.packages.bar ];
```
