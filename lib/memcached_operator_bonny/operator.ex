defmodule MemcachedOperatorBonny.Operator do
  @moduledoc false
  use GenServer

  alias MemcachedOperatorBonny.{AsyncStreamRunner, Config, Reconciler, RunnerSupervisor, Watcher}
  require Logger

  @log_prefix "#{__MODULE__} - " |> String.replace_leading("Elixir.", "")

  @spec start_link(map) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(config) when is_map(config) do
    GenServer.start_link(__MODULE__, config)
  end

  def reconcile(pid, payload) do
    GenServer.call(pid, {:reconcile, payload})
  end

  @impl true
  def init(config) do
    Logger.debug(@log_prefix <> "Starting operator with config: " <> inspect(config))

    {:ok, %{}, {:continue, {:init, config}}}
  end

  @impl true
  def handle_continue({:init, config}, state) do
    crds_ops = get_crd_operations(config)
    dependents_ops = get_dependents_operations(config)

    conn = Config.conn()

    crds_ops
    |> Enum.each(fn {_reconciler, list_operation} ->
      start_async_stream_runner(Watcher, conn, list_operation)
      start_async_stream_runner(Reconciler, conn, list_operation, 30_000)
    end)

    dependents_ops
    |> Enum.each(fn {_reconciler, list_operations} ->
      Enum.each(list_operations, fn list_operation ->
        start_async_stream_runner(Watcher, conn, list_operation)
      end)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_call({:reconcile, payload}, _from, state) do
    Logger.debug(@log_prefix <> "🔥🔥🔥 Received payload: " <> inspect(payload))

    {:reply, :ok, state}
  end

  defp get_crd_operations(operator) do
    group = operator.operator_group

    operator.controllers
    |> Enum.map(fn controller ->
      {controller.reconciler,
       K8s.Client.list(group <> "/" <> controller.crd_version, controller.crd_kind)}
    end)
  end

  defp get_dependents_operations(operator) do
    operator.controllers
    |> Enum.map(fn controller ->
      dependents =
        Enum.map(controller.dependents, fn d ->
          K8s.Client.list(d.dependent_api_version, d.dependent_kind)
          |> K8s.Selector.label({"app.kubernetes.io/managed-by", operator.operator_name})
        end)

      {controller.reconciler, dependents}
    end)
  end

  defp start_async_stream_runner(stream_module, conn, list_operation, termination_delay \\ 5_000) do
    DynamicSupervisor.start_child(
      RunnerSupervisor,
      {AsyncStreamRunner,
       stream: apply(stream_module, :get_stream, [self(), conn, list_operation]),
       termination_delay: termination_delay}
    )
  end
end
