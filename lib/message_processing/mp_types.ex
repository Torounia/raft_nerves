defmodule Raft.MessageProcessing.Types do
  @moduledoc """
  Module to hold all the MessageProcessing functions used by the MessageProcessing GenServer.
  """
  require Logger
  alias Raft.ElectionTimer, as: ElectionTimer
  alias Raft.HeartbeatTimer, as: HeartbeatTimer
  alias Raft.MessageProcessing.Helpers, as: Helpers
  alias Raft.Comms, as: Comms
  alias Raft.StateToDisk, as: DETS
  alias Raft.LogEnt

  def start_protocol(state) do
    state =
      if state.current_role == :follower do
        Logger.debug("Starting Raft protocol #{inspect(state)}")
        Logger.debug("Starting follower election timer")
        Logger.debug("MP-types election timer entry point: 1")
        ElectionTimer.start()
        state
      else
        Logger.error("Not follower state. Cannot start protocol")
      end

    state
  end

  def canditate(state) do
    state =
      if state.current_role != :leader do
        Logger.info("Starting election on node #{inspect(Node.self())}")
        Logger.debug("MP-types election timer entry point: 2")
        ElectionTimer.start()

        state = %{
          state
          | current_term: state.current_term + 1,
            current_role: :candidate,
            voted_for: Node.self(),
            votes_received: [Node.self() | state.votes_received] |> Enum.reverse(),
            runtime_stats: Map.put(state.runtime_stats, :last_election_duration, Time.utc_now())
        }

        DETS.write(state)
        last_term = Helpers.log_last_term(state)

        broadcast_payload =
          {:voteRequest, {Node.self(), state.current_term, Enum.count(state.log), last_term}}

        Comms.broadcast(
          state.peers,
          Node.self(),
          broadcast_payload
        )

        state
      else
        Logger.error(
          "Error. Running election while on leader role. Current state #{inspect(state)}"
        )

        state
      end

    state
  end

  def vote_request({c_Id, c_term, c_log_length, c_log_term}, state) do
    my_log_term = Helpers.log_last_term(state)

    log_ok =
      if c_log_term > my_log_term or
           (c_log_term == my_log_term and c_log_length >= Enum.count(state.log)) do
        true
      else
        false
      end

    term_ok =
      if c_term > state.current_term or
           (c_term == state.current_term and (state.voted_for == c_Id or state.voted_for == nil)) do
        true
      else
        false
      end

    state =
      if log_ok and term_ok do
        state = %{
          state
          | current_term: c_term,
            current_role: :follower,
            voted_for: c_Id,
            votes_received: []
        }

        Logger.info("New election, voting for #{inspect(c_Id)}")
        DETS.write(state)

        Comms.send_msg(
          Node.self(),
          c_Id,
          {:voteResponse, {Node.self(), state.current_term, true}}
        )

        Logger.debug("MP-types election timer entry point: 3")
        ElectionTimer.start()
        state
      else
        Comms.send_msg(
          Node.self(),
          c_Id,
          {:voteResponse, {Node.self(), state.current_term, false}}
        )

        state
      end

    state
  end

  def vote_response({voter_id, term, granded}, state) do
    Logger.debug("Entry - vote_response. state: #{inspect(state)}")

    state =
      if term > state.current_term do
        Logger.info(
          "Received higher term #{inspect(term)} from voter #{inspect(voter_id)}. Transitioning to :follower"
        )

        %{
          state
          | current_term: term,
            current_role: :follower,
            voted_for: nil,
            votes_received: []
        }
      else
        state
      end

    state =
      if state.current_role == :candidate and term == state.current_term and granded do
        Logger.debug(
          "Received a valid response from #{inspect(voter_id)}. term: #{inspect(state.current_term)}"
        )

        Logger.debug("Adding voter: #{inspect(voter_id)} to votes_received ")

        state = %{
          state
          | votes_received: [voter_id | state.votes_received] |> Enum.uniq() |> Enum.reverse()
        }

        state =
          if Helpers.check_quorum(state) do
            Logger.info(
              "Got majority of votes required for term: #{inspect(state.current_term)}. Transitioning to :leader state."
            )

            state = Helpers.init_leader_state(state)
            election_start_time = state.runtime_stats.last_election_duration

            state = %{
              state
              | runtime_stats:
                  Map.put(
                    state.runtime_stats,
                    :last_election_duration,
                    Time.diff(Time.utc_now(), election_start_time, :millisecond)
                  )
            }

            DETS.write(state)
            ElectionTimer.cancel()
            Helpers.replicate_log_all(state)
            HeartbeatTimer.start()

            state
          else
            state
          end

        state
      else
        state
      end

    Logger.debug("Exit - vote_response. state: #{inspect(state)}")
    state
  end

  def new_entry_to_log({entry, originator}, state) do
    Logger.debug("Entry - new_entry_to_log. state: #{inspect(state)}")

    state =
      if state.current_role == :leader do
        state = %{
          state
          | log:
              state.log ++ [%LogEnt{term: state.current_term, cmd: entry, originator: originator}]
        }

        state = %{
          state
          | acked_length: Map.put(state.acked_length, Node.self(), Enum.count(state.log))
        }

        DETS.write(state)
        Helpers.replicate_log_all(state)
        state
      else
        state
      end

    if state.current_role == :follower or state.current_role == :candidate do
      Logger.debug(
        "Received new log entry request. Current role #{inspect(state.current_role)} Sending to leader: #{inspect(state.current_leader)}"
      )

      Comms.send_msg(
        ## TODO, what if there is no leader to sent to? Also, do we need to send back a confirmation after commit?
        Node.self(),
        state.current_leader,
        {:logNewEntry, {entry, originator}}
      )
    end

    Logger.debug("Exit - new_entry_to_log. state: #{inspect(state)}")
    state
  end

  def log_request({leader_id, term, log_length, log_term, leader_commit, entries}, state) do
    # for debbuging purposes
    uniq_ref = make_ref()
    timer_start = Time.utc_now()

    Logger.debug(
      "Entry - log_request. uniq_ref: #{inspect(uniq_ref)}, timestamp: #{inspect(Time.utc_now())},  state: #{inspect(state)}"
    )

    state =
      if term > state.current_term do
        state = %{
          state
          | current_term: term,
            voted_for: nil,
            current_role: :follower,
            current_leader: leader_id,
            votes_received: []
        }

        Logger.info("Term #{inspect(term)} is > than current term #{inspect(state.current_term)}.
          Changing to follower role. New leader: #{inspect(state.current_leader)}")

        state
      else
        state
      end

    state =
      if term == state.current_term and state.current_role == :candidate do
        state = %{
          state
          | current_role: :follower,
            current_leader: leader_id,
            votes_received: []
        }

        Logger.info("Term #{inspect(term)} == current term #{inspect(state.current_term)}.
          Current role is #{inspect(state.current_role)}.
          Changing to follower role. New leader: #{inspect(state.current_leader)}")

        state
      else
        state
      end

    log_ok =
      if Enum.count(state.log) >= log_length and
           (log_length == 0 or log_term == Enum.fetch!(state.log, log_length - 1).term) do
        Logger.debug("log_ok is TRUE, timestamp: #{inspect(Time.utc_now())}")
        true
      else
        false
      end

    state =
      if term == state.current_term and log_ok do
        if state.current_leader == nil do
          Logger.info("Changing to follower role. New leader: #{inspect(leader_id)}")
        end

        state = %{
          state
          | current_role: :follower,
            current_leader: leader_id,
            votes_received: []
        }

        Logger.debug(
          "Term == current term and log_ok. Appending entries to the log, timestamp: #{inspect(Time.utc_now())}"
        )

        state = Helpers.append_entries(log_length, leader_commit, entries, state)
        acked = log_length + Enum.count(entries)

        Logger.debug(
          "Term == current term and log_ok. Saving state to disk, timestamp: #{inspect(Time.utc_now())}"
        )

        DETS.write(state)

        Raft.Comms.send_msg(
          Node.self(),
          leader_id,
          {:logResponse, {Node.self(), state.current_term, acked, true}}
        )

        Logger.debug(
          "MP-types election timer entry point: 4, timestamp: #{inspect(Time.utc_now())}"
        )

        case ElectionTimer.start() do
          :ok_timer_started ->
            Logger.debug("Election timer started")

          _ ->
            Logger.debug("Election timer not started. Trying again")
            ElectionTimer.start()
        end

        state
      else
        DETS.write(state)

        Raft.Comms.send_msg(
          Node.self(),
          leader_id,
          {:logResponse, {Node.self(), state.current_term, 0, false}}
        )

        Logger.debug("MP-types election timer entry point: 5")
        ElectionTimer.start()
        state
      end

    time_run = Time.diff(Time.utc_now(), timer_start, :millisecond)

    Logger.debug(
      "Exit - log_request. uniq_ref: #{inspect(uniq_ref)}. Func run time: #{inspect(time_run)}, timestamp: #{inspect(Time.utc_now())} state: #{inspect(state)}"
    )

    state
  end

  def log_response({follower, term, ack, success}, state) do
    uniq_ref = make_ref()

    Logger.debug("Entry - log_response. uniq_ref: #{inspect(uniq_ref)}. state: #{inspect(state)}")

    state =
      if term == state.current_term and state.current_role == :leader do
        if success == true and ack >= Map.get(state.acked_length, follower) do
          state = %{
            state
            | sent_length: Map.put(state.sent_length, follower, ack),
              acked_length: Map.put(state.acked_length, follower, ack)
          }

          state = Helpers.commit_log_entries(state)
          state
        else
          state =
            if Map.get(state.sent_length, follower) > 0 do
              state = %{
                state
                | sent_length:
                    Map.put(state.sent_length, follower, Map.get(state.sent_length, follower) - 1)
              }

              DETS.write(state)
              Helpers.replicate_log_single(follower, state)
              state
            else
              state
            end

          state
        end
      else
        state =
          if term > state.current_term do
            %{
              state
              | current_term: term,
                voted_for: nil,
                current_role: :follower
            }
          else
            state
          end

        DETS.write(state)
        state
      end

    Logger.debug("Exit - log_response. uniq_ref: #{inspect(uniq_ref)}. state: #{inspect(state)}")
    state
  end

  def heartbeat_timout(state) do
    uniq_ref = make_ref()

    Logger.debug(
      "Entry - heartbeat_timeout. uniq_ref: #{inspect(uniq_ref)}. state: #{inspect(state)}"
    )

    if state.current_role == :leader do
      Logger.debug("HeartBeat Timeout on #{inspect(state.current_role)}. Replicating Log")
      Helpers.replicate_log_all(state)
      HeartbeatTimer.start()
    end

    Logger.debug(
      "Exit - heartbeat_timeout. uniq_ref: #{inspect(uniq_ref)}. state: #{inspect(state)}"
    )
  end

  def send_current_state(dest, state) do
    Logger.debug("Sending a copy of the current state to #{inspect(dest)}")

    Raft.Comms.send_msg(
      Node.self(),
      dest,
      {:state_report, {Node.self(), state}}
    )

    state
  end
end
