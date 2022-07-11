defmodule MemcachedOperatorBonny.Watcher do
  @moduledoc """
  Creates the stream for watching resources in kubernetes and prepares its processing.

  Watching a resource in kubernetes results in a stream of add/modify/delete events.
  This module uses `K8s.Client.watch_and_stream/3` to create such a stream and maps
  events to a controller's event handler. It is then up to the caller to run the
  resulting stream.

  ## Example

      watch_stream = Bonny.Server.Watcher.get_stream(controller)
      Task.async(fn -> Stream.run(watch_stream) end)
  """

  alias MemcachedOperatorBonny.Operator

  @spec get_stream(pid(), K8s.Conn.t(), K8s.Operation.t()) :: Enumerable.t()
  def get_stream(pid, conn, watch_operation) do
    {:ok, watch_stream} = K8s.Client.watch_and_stream(conn, watch_operation)

    Stream.map(watch_stream, fn %{"type" => _type, "object" => resource} ->
      Operator.reconcile(pid, resource)
    end)
  end
end
