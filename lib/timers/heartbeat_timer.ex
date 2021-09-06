defmodule Raft.HeartbeatTimer do
  @moduledoc """
  Module to hold the heartbeat timer GenServer functions and configurations.
  As per the Raft protocol, the heartbeat timer is used by the leader node to send log_replication RPCs to follower nodes in the cluster.
  The Heartbeat timer GenServer has one public function used by the Raft protocol during runtime.
  TODO: Genserver function annotations, delete reset function
  """
  use GenServer
  require Logger
  alias Raft.MessageProcessing.Main, as: MP

  def start_link() do
    Logger.debug("Starting HeartbeatTimer GenServer")
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def start() do
    GenServer.cast(__MODULE__, :start_heartbeat_timer)
  end

  def init(%{}) do
    timeout = Application.fetch_env!(:raft, :heartbeat_timeout)
    {:ok, %{heartbeat_timer: nil, timeout: timeout, timer_start: nil}}
  end

  def handle_cast(:start_heartbeat_timer, %{
        heartbeat_timer: timer,
        timeout: timeout,
        timer_start: nil
      }) do
    {new_timer, new_timer_start} =
      if timer == nil do
        Logger.debug(
          "No heartbeat timer to reset. Starting new heartbeat timer, time now = #{inspect(Time.utc_now())}"
        )

        new_timer = Process.send_after(__MODULE__, :heartbeat, timeout)
        timer_start = Time.utc_now()
        Logger.debug("New heartbeat timer #{inspect(new_timer)}")
        {new_timer, timer_start}
      else
        Logger.debug("Cancelling election timer #{inspect(timer)}")
        Process.cancel_timer(timer)
        new_timer = Process.send_after(__MODULE__, :heartbeat, timeout)
        timer_start = Time.utc_now()
        Logger.debug("New timer heartbeat timer #{inspect(new_timer)}")
        {new_timer, timer_start}
      end

    {:noreply, %{heartbeat_timer: new_timer, timeout: timeout, timer_start: new_timer_start}}
  end

  def handle_info(:heartbeat, %{
        heartbeat_timer: timer,
        timeout: timeout,
        timer_start: timer_start
      }) do
    Logger.debug(
      "Heartbeat timeout for timer: #{inspect(timer)}, timer duration #{inspect(Time.diff(Time.utc_now(), timer_start, :millisecond))} "
    )

    if timer != nil do
      Process.cancel_timer(timer)
    end

    MP.heartbeat_timer_timeout(timer_start)
    {:noreply, %{heartbeat_timer: nil, timeout: timeout, timer_start: nil}}
  end
end
