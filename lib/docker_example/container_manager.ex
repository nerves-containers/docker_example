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
      # This is relevant because docker takes what’s in
      # /etc/resolv.conf (nothing at boot) and holds on to it, meaning containers
      # will never have working networking if it starts too early.
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
         "balena-engine-daemon",
         [
           "--data-root",
           "/data/balena",
           "--experimental"
         ],
         []
       ]}
    )

    Logger.info("Container Manager: Starting...")

    setup()

    {:noreply, state}
  end

  @impl true
  def handle_info(:waiting_for_balena_engine, state) do
    setup()

    {:noreply, state}
  end

  defp setup do
    if match?({_, 0}, System.cmd("balena-engine", ["info"])) do
      Logger.info("Balena Engine is running! Setting up docker compose...")

      {_, 0} =
        System.cmd("balena-engine", ["build", "-t", "docker/compose", "."],
          cd: Application.app_dir(:docker_example) <> "/priv/compose"
        )
        |> IO.inspect()

      compose(["up", "-d"])
    else
      Logger.info("Container Manager: Waiting for Balena Engine...")
      Process.send_after(self(), :waiting_for_balena_engine, 1000)
    end
  end

  defp priv_dir(folder) do
    Path.join([Application.app_dir(:docker_example), "priv", folder])
  end

  defp compose(command_list) do
    {_, 0} =
      System.cmd(
        "balena-engine",
        [
          "run",
          "--rm",
          "-e",
          "HOME=/root",
          "-w",
          priv_dir("app"),
          "-v",
          "/root/.balena-engine:/root/.docker",
          "-v",
          "/var/run/balena-engine.sock:/var/run/docker.sock",
          "-v",
          priv_dir("app") <> ":" <> priv_dir("app"),
          "docker/compose",
          "compose"
        ] ++ command_list
      )
      |> IO.inspect()
  end
end
