defmodule Raft.DETS do
  @moduledoc """
  Module to hold the DETS functions used by the Raft.StateToDisk GenServer
  """
  require Logger

  @doc """
  Stores val to disk after converting it to binary format
  ## Parameters
  
    - val: The term that will writen to file on disk.
  """
  @spec store(term) :: no_return

  def store(val) do
    toSave = %{
      lastWriteUTC: DateTime.utc_now(),
      data: val
    }

    bin = :erlang.term_to_binary(toSave)
    # TODO error catcher
    name = "sState_" <> Atom.to_string(Node.self())
    # File.write(name, bin)
    :ok
  end

  @doc """
  Retrives the binary files from disk, convert to term from binary and returns to calling function
  ## Parameters
  
    - No parameters
  
  """
  @spec fetch() :: term

  def fetch do
    name = "sState_" <> Atom.to_string(Node.self())

    Logger.debug("Fetching binary file #{inspect(name)} from local storage")

    case File.read(name) do
      {:ok, value} ->
        try do
          {:ok, value |> :erlang.binary_to_term()}
        rescue
          error in ArgumentError ->
            Logger.error(
              "Error #{inspect(error)} while fetching binary file #{inspect(name)} from local storage"
            )

            {:error, :enoent}
        end

      {:error, :enoent} ->
        {:error, :enoent}
    end
  end
end
