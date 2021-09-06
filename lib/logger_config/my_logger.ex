defmodule Raft.LogFormatter do
  @pattern Logger.Formatter.compile("$time [$level][$metadata]$message\n")

  def format(level, message, timestamp, metadata) do
    Logger.Formatter.format(@pattern, level, message, timestamp, [{:node, Node.self()} | metadata])
  end
end
