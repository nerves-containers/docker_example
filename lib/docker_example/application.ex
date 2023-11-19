defmodule DockerExample.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DockerExample.Supervisor]

    if target() != :host do
      # create directories for podman
      File.mkdir_p("/root/podman-cni")
      File.mkdir_p("/root/podman-tmp")
      File.mkdir_p("/root/podman-tmp/net.d")
      File.mkdir_p("/root/podman-storage")

      # TODO: find a better solution
      File.cp!("/etc/cni/net.d/87-podman-bridge.conflist", "/root/podman-tmp/net.d/87-podman-bridge.conflist")
      System.cmd("mount", ["--bind", "/root/podman-tmp/net.d", "/etc/cni/net.d"])
    end

    children =
      [
        # Children for all targets
        # Starts a worker by calling: DockerExample.Worker.start_link(arg)
        # {DockerExample.Worker, arg},
      ] ++ children(target())

    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      # Children that only run on the host
      # Starts a worker by calling: DockerExample.Worker.start_link(arg)
      # {DockerExample.Worker, arg},
    ]
  end

  def children(_target) do
    [
      # Children for all targets except host
      # Start a NervesSSH instance that listens on port 2222 using a normal shell
      {NervesSSH,
       NervesSSH.Options.with_defaults(
         Application.get_all_env(:nerves_ssh)
         |> Keyword.merge(
           name: :shell,
           port: 2222,
           shell: :disabled,
           daemon_option_overrides: [
             ssh_cli: {NervesSSH.SystemShell, []},
             tcpip_tunnel_out: true,
             tcpip_tunnel_in: true
           ]
         )
       )},
      # the dynamic supervisor starts the balena-engine
      {DynamicSupervisor, name: DockerExample.DynamicSupervisor, strategy: :one_for_one},
      DockerExample.ContainerManager
    ]
  end

  def target() do
    Application.get_env(:docker_example, :target)
  end
end
