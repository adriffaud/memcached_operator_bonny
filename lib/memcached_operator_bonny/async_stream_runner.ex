defmodule MemcachedOperatorBonny.AsyncStreamRunner do
  @moduledoc """
  Runs the given stream in a separate process. Prepare your stream and add this Runner to your supervision tree
  in order to control it (e.g. restart after the stream ends).

  ## Example
      # prepare a stream
      stream =
        conn
        |> K8s.Client.stream(operation)
        |> Stream.filter(&filter_resources/1)
        |> Stream.map(&process_stream/1)

      children = [
        {Bonny.Server.AsyncStreamRunner,
           name: ReconcileServer,
           stream: K8s.Client.stream(conn, operation),
           termination_delay: 30_000,
      ]

      Supervisor.init(children, strategy: :one_for_one)

  ## Options

    * `:stream` - The (prepared) stream to run
    * `:name` (optional) - Register this process under the given name.
    * `:termination_delay` (optional) - After the stream ends, how many
      milliseconds to wait before the process terminates (and might be
      restarted by the Supervisor). Per default there's no delay

  """

  require Logger

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [args]},
      restart: :permanent
    }
  end

  @spec start_link(keyword()) :: {:ok, pid}
  def start_link(args) do
    name = Keyword.get(args, :name)
    stream = Keyword.fetch!(args, :stream)
    termination_delay = Keyword.get(args, :termination_delay)

    Logger.debug("Starting #{name}")

    {:ok, pid} = Task.start_link(__MODULE__, :run, [stream, termination_delay])

    {:ok, pid}
  end

  @spec run(Enumerable.t(), non_neg_integer()) :: no_return()
  def run(stream, termination_delay) do
    Stream.run(stream)

    Logger.debug("Stream terminated")

    if !is_nil(termination_delay), do: Process.sleep(termination_delay)
  end
end
