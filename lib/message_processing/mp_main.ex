defmodule Raft.MessageProcessing.Main do
  use GenServer
  require Logger

  alias Raft.MessageProcessing.Types, as: MP_types

  # client API

  def start_link(state) do
    Logger.debug("Starting MessageProcessing GenServer")
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def election_timer_timeout do
    GenServer.cast(__MODULE__, :election_timer_timeout)
  end

  def heartbeat_timer_timeout(time) do
    GenServer.cast(__MODULE__, {:heartbeat_timer_timeout, time})
  end

  def start_protocol() do
    send(__MODULE__, :start_protocol)
  end

  def received_msg(msg) do
    GenServer.cast(__MODULE__, {:received_msg, msg})
  end

  def show_current_state() do
    state = GenServer.call(__MODULE__, :show_current_state)
    state
  end

  def new_entry(msg, originator) do
    GenServer.cast(__MODULE__, {:new_entry, {msg, originator}})
  end

  # callbacks
  def init(state) do
    {:ok, state}
  end

  def handle_call(:show_current_state, _from, state) do
    # Logger.info("Current state: #{inspect(state)}")
    {:reply, state, state}
  end

  def handle_cast(:election_timer_timeout, state) do
    new_state = MP_types.canditate(state)
    {:noreply, new_state}
  end

  def handle_cast({:heartbeat_timer_timeout, timer}, state) do
    Logger.debug(
      "Heartbeat to MP duration #{inspect(Time.diff(Time.utc_now(), timer, :millisecond))} "
    )

    MP_types.heartbeat_timout(state)
    {:noreply, state}
  end

  def handle_cast({:received_msg, msg}, state) do
    new_state =
      case msg do
        {:voteRequest, payload} ->
          Logger.debug("Received voteRequest. Sending to MessageProcessing")
          MP_types.vote_request(payload, state)

        {:voteResponse, payload} ->
          Logger.debug("Received voteResponse. Sending to MessageProcessing")
          MP_types.vote_response(payload, state)

        {:logNewEntry, payload} ->
          Logger.debug("Received logNewEntry. Sending to MessageProcessing")
          MP_types.new_entry_to_log(payload, state)

        {:logRequest, payload} ->
          Logger.debug("Received logRequest. Sending to MessageProcessing")
          MP_types.log_request(payload, state)

        {:logResponse, payload} ->
          Logger.debug("Received logResponse. Sending to MessageProcessing")
          MP_types.log_response(payload, state)

        {:startProtocol, _payload} ->
          Logger.debug("Received startProtocol.Sending to MessageProcessing")
          MP_types.start_protocol(state)

        {:startCandidate, _payload} ->
          Logger.debug("Received startProtocol.Sending to MessageProcessing")
          MP_types.canditate(state)

        {:terminateNode, _payload} ->
          Logger.debug("Terminating Node")
          :init.stop()

        {:ok_commited, payload} ->
          Logger.info("Command #{inspect(payload)} has been commited on all nodes")
          state

        {:report_state, payload} ->
          Logger.info(
            "Current State requested from #{inspect(payload)}. Sending to MessageProcessing"
          )

          MP_types.send_current_state(payload, state)

        {:newLeader, payload} ->
          Logger.info(
            "New leader election request from #{inspect(payload)}. Sending to MessageProcessing"
          )

          :timer.sleep(2000)
          # MP_types.canditate(state)
      end

    # Logger.debug("New state = #{inspect(new_state)}")
    {:noreply, new_state}
  end

  def handle_cast({:new_entry, {msg, originator}}, state) do
    Logger.debug("Received new log entry. Sending to MessageProcessing")
    new_state = MP_types.new_entry_to_log({msg, originator}, state)

    {:noreply, new_state}
  end

  def handle_info(:start_protocol, state) do
    MP_types.start_protocol(state)
    {:noreply, state}
  end
end
