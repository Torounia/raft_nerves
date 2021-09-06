defmodule Raft.ElectionTimer do
  @moduledoc """
  Module to hold the election timer GenServer functions and configurations.
  As per the Raft protocol, the election timer is used by the cluster nodes to monitor leader health state.
  If no log_replication RPCs are received from the leader for the duration of the election timer, the node is switching to canditate role and starts the leader election process to become the new leader.

  The ElectionTimer GenServer has four public functions used by the Raft protocol during runtime.
  TODO: Genserver function annotations, delete reset function
  """
  use GenServer
  require Logger
  alias Raft.MessageProcessing.Main, as: MP
  alias Raft.RandTimer

  def start_link() do
    Logger.debug("Starting ElectionTimer GenServer")
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def start() do
    GenServer.call(__MODULE__, :start_election_timer)
  end

  def cancel() do
    GenServer.cast(__MODULE__, :cancel_election_timer)
  end

  def show_status() do
    GenServer.cast(__MODULE__, :show_status)
  end

  def init(%{}) do
    {:ok, %{election_timer: nil, timerID: 0}}
  end

  # def handle_cast(:start_election_timer, %{election_timer: nil, timerID: timer_ID}) do
  #   timeout = RandTimer.rand_election_timeout()
  #   timer = Process.send_after(__MODULE__, :work, timeout)
  #   new_timer_ID = timer_ID + 1
  #   Logger.debug("Starting election timer for #{inspect(timeout)} ms, timer: #{inspect(timer)} ID: #{inspect(new_timer_ID)}")
  #   {:noreply, %{election_timer: timer, timerID: new_timer_ID}}
  # end

  def handle_call(:start_election_timer, _from, %{election_timer: timer, timerID: timer_ID}) do
    {new_timer, new_timer_ID} =
      if timer == nil do
        Logger.debug("No timer to reset. Starting new timer")
        timeout = RandTimer.rand_election_timeout()
        new_timer = Process.send_after(__MODULE__, :work, timeout)
        time_now = Time.utc_now()
        new_timer_ID = timer_ID + 1

        Logger.debug(
          "New timer election timer for #{inspect(timeout)} ms, time: #{inspect(new_timer)}, ID: #{
            inspect(new_timer_ID)
          }, time now (logger) = #{inspect(Time.utc_now())}, timenow (not logger) = #{
            inspect(time_now)
          }"
        )

        {new_timer, new_timer_ID}
      else
        Logger.debug("Reseting election timer #{inspect(timer)}, ID: #{inspect(timer_ID)}")
        Process.cancel_timer(timer)
        Logger.debug("Cancelling election timer #{inspect(timer)}, ID: #{inspect(timer_ID)}")
        timeout = RandTimer.rand_election_timeout()
        new_timer = Process.send_after(__MODULE__, :work, timeout)
        time_now = Time.utc_now()
        new_timer_ID = timer_ID + 1

        Logger.debug(
          "New timer election timer for #{inspect(timeout)} ms, time: #{inspect(new_timer)}, ID: #{
            inspect(new_timer_ID)
          }, time now (logger) = #{inspect(Time.utc_now())}, timenow (not logger) = #{
            inspect(time_now)
          }"
        )

        {new_timer, new_timer_ID}
      end

    {:reply, :ok_timer_started, %{election_timer: new_timer, timerID: new_timer_ID}}
  end

  def handle_cast(:cancel_election_timer, %{election_timer: timer, timerID: timer_ID}) do
    Logger.debug("Cancelling election timer #{inspect(timer)}, ID: #{inspect(timer_ID)}")

    if timer != nil do
      Process.cancel_timer(timer)
    end

    {:noreply, %{election_timer: nil, timerID: timer_ID}}
  end

  def handle_cast(:show_status, %{election_timer: timer, timerID: timer_ID}) do
    Logger.debug("Election timer Genserver status: #{inspect(timer)}, ID: #{inspect(timer_ID)}")
    {:noreply, %{election_timer: timer, timerID: timer_ID}}
  end

  def handle_info(:work, %{election_timer: timer, timerID: timer_ID}) do
    time_now = Time.utc_now()

    Logger.debug(
      "Election timeout for timer: #{inspect(timer)}, ID: #{inspect(timer_ID)}, time now (logger) = #{
        inspect(Time.utc_now())
      }, timenow (not logger) = #{inspect(time_now)}"
    )

    Logger.debug("Cancelling election timer #{inspect(timer)}, ID: #{inspect(timer_ID)}")

    if timer != nil do
      Process.cancel_timer(timer)
    end

    MP.election_timer_timeout()
    {:noreply, %{election_timer: nil, timerID: timer_ID}}
  end
end
