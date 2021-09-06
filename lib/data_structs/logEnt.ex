defmodule Raft.LogEnt do
  @typedoc """
  custom map structure representing a single log entity.
  term refers to the current leader election round and cmd is the message or command to be delivered/ approved and commited by all nodes in the cluster
  """
  defstruct [:term, :cmd, :originator]
  @type log :: %__MODULE__{term: non_neg_integer(), cmd: term(), originator: atom()}
end
