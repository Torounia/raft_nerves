defmodule Raft.StateEnt do
  @typedoc """
  # latest term server has seen (initialized to 0 on first boot, increases monotonically)
  # int that increments everytime new leader election happens
  current_term: sstable.current_term,

  # candidateId that received vote in current term (or null if none)
  voted_for: sstable.voted_for,

  # Replicated log ( has )
  log: sstable.log,

  # how far we have commited (or agrred) along the log with the rest of the nodes
  commit_length: sstable.commit_length,

  # index of highest log entry known to be committed (initialized to 0, increases monotonically)
  commit_index: 0,

  # index of highest log entry applied to state machine (initialized to 0, increases monotonically)
  last_applied: 0,

  # current role (always a follower at first start)
  current_role: :follower,
  votes_received: [],
  sent_length: nil,
  acked_length: nil,
  current_leader: nil,
  peers: %Configurations{}.peers,
  cluster_size: Enum.count(%Configurations{}.peers)

  """
  defstruct([
    :current_term,
    :voted_for,
    :log,
    :current_role,
    :votes_received,
    :sent_length,
    :acted_length,
    :current_leader,
    :peers,
    :cluster_size
  ])

  @type state() :: %__MODULE__{
          current_term: non_neg_integer(),
          voted_for: atom(),
          log: Raft.LogEnt.log(),
          current_role: atom(),
          votes_received: list(),
          sent_length: map(),
          acted_length: map(),
          current_leader: atom(),
          peers: list(),
          cluster_size: non_neg_integer()
        }
end
