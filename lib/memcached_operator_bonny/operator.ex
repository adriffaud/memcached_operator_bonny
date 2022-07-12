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

  @spec reconcile(pid, map) :: term
  def reconcile(pid, payload) do
    GenServer.call(pid, {:reconcile, payload})
  end

  @impl true
  def init(config) do
    Logger.debug(@log_prefix <> "Starting operator with config: " <> inspect(config))

    {:ok, [], {:continue, {:init, config}}}
  end

  @impl true
  def handle_continue({:init, config}, _state) do
    crds_ops = get_crd_operations(config)
    dependents_ops = get_dependents_operations(config)

    controllers =
      config.controllers
      |> Enum.map(fn controller -> {controller.crd_kind, controller.reconciler} end)

    conn = Config.conn()

    crds_ops
    |> Enum.each(fn {_reconciler, list_operation} ->
      start_async_stream_runner(Watcher, conn, list_operation)
      start_async_stream_runner(Reconciler, conn, list_operation, 30_000)
    end)

    dependents_ops
    |> Enum.each(fn {_reconciler, list_operation} ->
      start_async_stream_runner(Watcher, conn, list_operation)
    end)

    {:noreply, controllers}
  end

  @impl true
  def handle_call({:reconcile, payload}, _from, state) do
    %{"apiVersion" => api_version, "kind" => kind, "metadata" => metadata} = payload
    %{"name" => name, "namespace" => namespace} = metadata

    Logger.info(@log_prefix <> "📥 Received #{kind} event")

    app_crds = state |> Enum.map(fn {kind, _} -> kind end) |> MapSet.new()

    to_call =
      if MapSet.member?(app_crds, kind) do
        %{"apiVersion" => api_version, "kind" => kind, "name" => name, "namespace" => namespace}
      else
        %{"ownerReferences" => owner_references} = metadata

        owner =
          owner_references
          |> Enum.find(fn %{"kind" => kind} -> MapSet.member?(app_crds, kind) end)

        %{owner | "namespace" => namespace}
      end

    Logger.debug(@log_prefix <> "Calling controller for: " <> inspect(to_call))

    {_kind, module} = Enum.find(state, fn {kind, _module} -> kind == Map.get(to_call, "kind") end)

    apply(module, :reconcile, [to_call])

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
    Enum.flat_map(operator.controllers, fn controller ->
      Enum.map(controller.dependents, fn d ->
        {controller.reconciler,
         K8s.Client.list(d.dependent_api_version, d.dependent_kind)
         |> K8s.Selector.label({"app.kubernetes.io/managed-by", operator.operator_name})}
      end)
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
