defmodule Raft.StateToDisk do
  @moduledoc """
  Module to hold the GenServer used as the StableStorage layer to store the state to the disk. Is is implemented using Erlangs's DETS functionallity to store the data in binary format.
  """
  use GenServer
  require Logger

  def start_link() do
    Logger.debug("Starting StateToDisk GenServer")
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def write(raft_state) do
    GenServer.cast(__MODULE__, {:write, raft_state})
  end

  def init(state) do
    {:ok, state}
  end

  def handle_cast({:write, raft_state}, state) do
    state_to_save = %{
      current_term: raft_state.current_term,
      voted_for: raft_state.voted_for,
      log: raft_state.log,
      commit_length: raft_state.commit_length
    }

    case Raft.DETS.store(state_to_save) do
      :ok -> Logger.debug("State saved to disk")
      {:error, type} -> Logger.debug("Error while saving state to disk: #{inspect(type)}")
    end

    {:noreply, state}
  end
end
