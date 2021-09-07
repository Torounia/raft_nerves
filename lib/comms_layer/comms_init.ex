defmodule Raft.ClusterConfig do
  @doc """
  Functions related to cluster communication management
  """
  require Logger

  def init(state) do
    Logger.debug("Checking networking connection status")

    check_net_status()

    Logger.debug("Enabling EPMD ")

    case System.cmd("epmd", ["-daemon"]) do
      {"", 0} -> Logger.debug("OK. EPMD started ")
      _ -> Logger.error("Error. Cannot start EPMD")
    end

    {:ok, host_name} = :inet.gethostname()

    host_name_s = to_string(host_name)
    node_name = (host_name_s <> "@" <> host_name_s <> ".local") |> String.to_atom()

    Logger.debug("Starting distributed node #{inspect(node_name)}")

    case Node.start(node_name) do
      {:ok, pid} ->
        Logger.debug("OK started pid: #{inspect(pid)}")

      _ ->
        Logger.error("Node cannot start}")
    end

    Logger.debug("Setting cookie")

    cookie = Application.get_env(:raft, :cookie)

    case Node.set_cookie(cookie) do
      true ->
        Logger.debug("Setting cookie.. OK")

      _ ->
        Logger.error("Error while setting cookie}")
    end

    Logger.debug("Registering Global name and syncing..")

    :global.register_name(Node.self(), self())
    :global.sync()
    Logger.debug("Other globally registered nodes: #{inspect(:global.registered_names())}")

    nodes_not_self = Enum.filter(state.peers, fn node -> node != Node.self() end)
    Logger.debug("Conneting to other nodes")

    Enum.each(nodes_not_self, fn node ->
      if Node.connect(node) do
        Logger.debug("Connected to #{inspect(node)}")
      else
        Logger.debug("Cannot establish connection with #{inspect(node)}")
      end
    end)

    Logger.info("Connected to nodes: #{inspect(Node.list())}")
    Atom.to_string(Node.self())
  end

  def check_net_status() do
    wlan_status = VintageNet.get(["interface", "wlan0", "connection"])

    case wlan_status do
      :internet ->
        Logger.info("Networking configured to :internet")

      _ ->
        Logger.warning("Networking not configured. Trying again in 5 seconds")
        :timer.sleep(5000)
        check_net_status()
    end
  end
end
