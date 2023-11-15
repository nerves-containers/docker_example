defmodule DockerExample.ContainerManager do
  use GenServer

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, nil, {:continue, :wait_for_internet}}
  end

  @impl true
  def handle_continue(:wait_for_internet, state) do
    if VintageNet.get(["connection"]) == :internet do
      {:noreply, state, {:continue, :do_start}}
    else
      Logger.info("Container Manager: Waiting for internet connection...")
      # This is relevant because docker / podman takes what’s in
      # /etc/resolv.conf (nothing at boot) and holds on to it, meaning a container started
      # too ealry will never have working networking (dns).
      #
      # For simplicity we simply wait until VintageNet says we have working internet.
      # This should be adapted if internet is not needed for the application to work,
      # e.g., because a docker registry on the local LAN is used.

      Process.sleep(:timer.seconds(1))

      {:noreply, state, {:continue, :wait_for_internet}}
    end
  end

  def handle_continue(:do_start, state) do
    # start daemon only after internet is available, see above
    DynamicSupervisor.start_child(
      DockerExample.DynamicSupervisor,
      {MuonTrap.Daemon,
       [
         "/usr/local/bin/podman",
         [
           "system",
           "service",
           "--time",
           "0",
           "unix:///var/run/podman.sock"
         ],
         [
           env: [
             {"PATH", "/usr/local/bin:#{System.get_env("PATH")}"},
             {"TMPDIR", "/root/podman-tmp"}
           ]
         ]
       ]}
    )

    Logger.info("Container Manager: Starting...")

    setup()

    {:noreply, state}
  end

  @impl true
  def handle_info(:waiting_for_podman_service, state) do
    setup()

    {:noreply, state}
  end

  defp setup do
    if ready?() do
      Logger.info("Container Manager: podman service is running! Setting up docker compose...")

      compose(["up", "-d"])
    else
      Logger.info("Container Manager: Waiting for Balena Engine...")
      Process.send_after(self(), :waiting_for_podman_service, 1000)
    end
  end

  defp ready? do
    :httpc.set_options([
      {:ipfamily, :local},
      {:unix_socket, ~c"/var/run/podman.sock"}
    ])

    case :httpc.request(:get, {~c"http:///v1.40/info", []}, [], []) do
      {:ok, {{_, 200, ~c"OK"}, _, _}} ->
        true

      other ->
        Logger.info("Container Manager: Waiting for podman socket... got: #{inspect(other)}")
        false
    end
  end

  defp priv_dir(folder) do
    Path.join([Application.app_dir(:docker_example), "priv", folder])
  end

  defp podman(command_list, opts \\ []) do
    {_, 0} =
      System.cmd(
        "/usr/local/bin/podman",
        ["--url", "unix:/var/run/podman.sock"] ++ command_list,
        [
          env: [
            {"PATH", "/usr/local/bin:#{System.get_env("PATH")}"},
            {"TMPDIR", "/root/podman-tmp"},
            {"DOCKER_HOST", "unix:///var/run/podman.sock"}
          ]
        ] ++ opts
      )
      |> IO.inspect()
  end

  defp compose(command_list) do
    podman(["compose"] ++ command_list, cd: priv_dir("app"))
  end
end
