defmodule Raft.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  alias Raft.{
    InitStateVar
  }

  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Raft.Supervisor]

    init_arg = init()

    children =
      [
        %{
          id: Raft.Comms,
          start: {Raft.Comms, :startServer, [init_arg]}
        },
        %{
          id: Raft.MessageProcessing.Main,
          start: {Raft.MessageProcessing.Main, :start_link, [init_arg]}
        },
        %{
          id: Raft.ElectionTimer,
          start: {Raft.ElectionTimer, :start_link, []}
        },
        %{
          id: Raft.HeartbeatTimer,
          start: {Raft.HeartbeatTimer, :start_link, []}
        },
        %{
          id: Raft.StateToDisk,
          start: {Raft.StateToDisk, :start_link, []}
        }
        # Children for all targets
        # Starts a worker by calling: Raft.Worker.start_link(arg)
        # {Raft.Worker, arg},
      ] ++ children(target())

    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      # Children that only run on the host
      # Starts a worker by calling: Raft.Worker.start_link(arg)
      # {Raft.Worker, arg},
    ]
  end

  def children(_target) do
    [
      # Children for all targets except host
      # Starts a worker by calling: Raft.Worker.start_link(arg)
      # {Raft.Worker, arg},
    ]
  end

  def target() do
    Application.get_env(:raft, :target)
  end

  def init() do
    Logger.info("Starting Raft consensus module")
    Logger.info("Initialising state")
    nodes = Application.fetch_env!(:raft, :peers)
    InitStateVar.initVariables(nodes)
  end
end
