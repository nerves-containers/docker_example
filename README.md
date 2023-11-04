# DockerExample

This is an example project that runs a Node.js application in a Docker container on a Nerves device.
Tested on x86_64 in QEMU. Note that the generated disk image from `mix firmware.image disk.img` has a too small
application partition and the container build will run out of space. This should probably be fixed
in the nerves_containers_x86_64 repo, but for now booting something like the gparted live iso and manually
creating a larger partition works, after running `qemu-img resize disk.img +20G`.

When everything works, a http server should be running on port 80 on the device after a couple of minutes.
This can take a while as the container is built on the device. For real deployment, you would probably include
a prebuilt container image in the firmware, which can then be [imported](https://docs.docker.com/engine/reference/commandline/import/).

## Docker commands

Instead of `docker`, you need to write `balena-engine` instead. For example:

```elixir
iex> cmd "balena-engine run --rm ubuntu:jammy echo hello"
```

## SSH Shell

A custom SSH server listens on port 2222 and allows you to use a normal shell,
which can be more convenient than using `cmd` or `System.cmd` inside iex.

## Targets

Nerves applications produce images for hardware targets based on the
`MIX_TARGET` environment variable. If `MIX_TARGET` is unset, `mix` builds an
image that runs on the host (e.g., your laptop). This is useful for executing
logic tests, running utilities, and debugging. Other targets are represented by
a short name like `rpi3` that maps to a Nerves system image for that platform.
All of this logic is in the generated `mix.exs` and may be customized. For more
information about targets see:

https://hexdocs.pm/nerves/targets.html#content

## Getting Started

To start your Nerves app:
  * `export MIX_TARGET=my_target` or prefix every command with
    `MIX_TARGET=my_target`. For example, `MIX_TARGET=rpi3`
  * Install dependencies with `mix deps.get`
  * Create firmware with `mix firmware`
  * Burn to an SD card with `mix burn`

## Learn more

  * Official docs: https://hexdocs.pm/nerves/getting-started.html
  * Official website: https://nerves-project.org/
  * Forum: https://elixirforum.com/c/nerves-forum
  * Discussion Slack elixir-lang #nerves ([Invite](https://elixir-slackin.herokuapp.com/))
  * Source: https://github.com/nerves-project/nerves
