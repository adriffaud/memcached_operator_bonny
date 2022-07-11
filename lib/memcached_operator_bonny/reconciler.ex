defmodule MemcachedOperatorBonny.Reconciler do
  @moduledoc """
  Creates a stream that, when run, streams a list of resources and calls `reconcile/1`
  on the given controller for each resource in the stream in parallel.

  ## Example

      reconciliation_stream = Bonny.Server.Reconciler.get_stream(controller)
      Task.async(fn -> Stream.run(reconciliation_stream) end)
  """

  @doc """
  Takes a controller that must define the following functions and returns a (prepared) stream.

  * `conn/0` - should return a K8s.Conn.t()
  * `reconcile_operation/0` - should return a K8s.Operation.t() list operation that produces the stream of resources
  * `reconcile/1` - takes a map and processes it
  """

  alias MemcachedOperatorBonny.Operator

  require Logger

  @callback reconcile(map()) :: :ok | {:ok, any()} | {:error, any()}

  @spec get_stream(pid(), K8s.Conn.t(), K8s.Operation.t(), keyword()) :: Enumerable.t()
  def get_stream(pid, conn, reconcile_operation, opts \\ []) do
    {:ok, reconciliation_stream} = K8s.Client.stream(conn, reconcile_operation, opts)
    reconcile_all(reconciliation_stream, pid)
  end

  defp reconcile_all(resource_stream, pid) do
    resource_stream
    |> Stream.map(fn
      resource when is_map(resource) ->
        Operator.reconcile(pid, resource)
        resource

      {:error, error} ->
        Logger.debug("Reconciler fetch failed", error)

        error
    end)
  end
end
