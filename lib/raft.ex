defmodule Raft do
  @moduledoc """
  Main Raft Module. Entry point of the application. Contains the initialisation function, and other Raft control functions.
  TODO: Move init() to another module
  """

  alias Raft.{
    MessageProcessing.Main
  }

  require Logger

  def start do
    Main.start_protocol()
  end

  def add_to_log(cmd) do
    Main.new_entry(cmd, Node.self())
  end

  def current_state() do
    state = Main.show_current_state()
    Logger.info(inspect(state))
  end

  def current_leader() do
    state = Main.show_current_state()
    Logger.info(inspect(state.current_leader))
  end

  def current_log() do
    state = Main.show_current_state()
    Logger.info(inspect(state.log))
  end
end
