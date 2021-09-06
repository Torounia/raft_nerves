defmodule Raft.Comms do
  use GenServer
  require Logger
  alias Raft.ClusterConfig, as: ClusterConfig
  alias Raft.MessageProcessing.Main, as: MP
  # client API

  def startServer(state) do
    Logger.debug("Starting Comms GenServer")
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def broadcast(nodes, source, msg) do
    nodes_not_self = Enum.filter(nodes, fn node -> node != Node.self() end)
    Logger.debug("[Broadcasting #{inspect(msg)} to #{inspect(nodes_not_self)}")

    GenServer.abcast(nodes_not_self, __MODULE__, {:broadcast, source, msg})
  end

  def send_msg(source, dest, msg) do
    case :global.whereis_name(dest) do
      :undefined ->
        Logger.debug("Cannot find #{inspect(dest)} in the cluster")

      pid ->
        Logger.debug(
          "Sending #{inspect(msg)} to #{inspect(dest)} @ #{inspect(:global.whereis_name(dest))}"
        )

        GenServer.cast(pid, {:sendMsg, source, msg})
    end
  end

  # callbacks
  def init(state) do
    ClusterConfig.init(state)
    {:ok, state}
  end

  def handle_cast({:broadcast, source, msg}, state) do
    Logger.debug(
      "Received broadcast #{inspect(msg)} from #{inspect(source)}. Sending to Raft.MessageProcessing.Main"
    )

    MP.received_msg(msg)
    {:noreply, state}
  end

  def handle_cast({:sendMsg, source, msg}, state) do
    Logger.debug(
      "Received msg #{inspect(msg)} from #{inspect(source)}. Sending to Raft.MessageProcessing.Main"
    )

    MP.received_msg(msg)
    {:noreply, state}
  end

  def handle_info(something, :ok) do
    Logger.debug("Received something #{inspect(something)}")
  end

  def handle_info({something, :ok}, _) do
    Logger.debug("Received something #{inspect(something)}")
  end
end
