defmodule Raft.RandTimer do
  def rand_election_timeout do
    min = Application.fetch_env!(:raft, :min_election_timeout)
    max = Application.fetch_env!(:raft, :max_election_timeout)
    Enum.random(min..max)
  end
end
