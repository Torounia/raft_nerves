defmodule Raft.InitStateVar do
  require Logger

  alias Raft.{
    DETS
  }

  def initVariables(nodes) do
    sstable = initStableState()

    state = %{
      current_term: sstable.current_term,
      voted_for: sstable.voted_for,
      log: sstable.log,
      commit_length: sstable.commit_length,
      current_role: :follower,
      votes_received: [],
      sent_length: nil,
      acked_length: nil,
      current_leader: nil,
      peers: nodes,
      cluster_size: length(nodes),
      runtime_stats: %{
        last_election_duration: nil
      }
    }

    Logger.debug("state: #{inspect(state)}")
    state
  end

  def initStableState do
    # First look for disk state, if nothing, initialise new sState and return

    case DETS.fetch() do
      {:ok, stateFromFile} ->
        Logger.info("Found stable state on disk dated: #{inspect(stateFromFile.lastWriteUTC)}")
        Logger.info("Previous State on disk: #{inspect(stateFromFile.data)}")
        stateFromFile.data

      {:error, :enoent} ->
        Logger.info("No stable state on disk found. Initialising to defaults")

        %{
          current_term: 0,
          voted_for: nil,
          log: [],
          commit_length: 0
        }
    end
  end
end
