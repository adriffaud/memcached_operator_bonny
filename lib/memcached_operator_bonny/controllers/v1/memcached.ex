defmodule MemcachedOperatorBonny.Controller.V1.Memcached do
  @moduledoc false
  @behaviour Bonny.Controller
  require Logger

  @scope :namespaced
  @names %{
    plural: "memcached",
    singular: "memcached",
    kind: "Memcached",
    shortNames: []
  }

  # @rule {"apps", ["deployments"], ["*"]}
  # @rule {"", ["pods"], ["*"]}

  def crd() do
    %Bonny.CRD{
      group: Bonny.Config.group(),
      scope: @scope,
      version: Bonny.Naming.module_version(__MODULE__),
      names: @names,
      additional_printer_columns: Bonny.CRD.default_columns()
    }
  end

  @doc """
  Handles an `ADDED` event
  """
  @spec add(map()) :: :ok | :error
  @impl Bonny.Controller
  def add(%{} = payload), do: reconcile(payload)

  @doc """
  Handles a `MODIFIED` event
  """
  @spec modify(map()) :: :ok | :error
  @impl Bonny.Controller
  def modify(%{} = payload), do: reconcile(payload)

  @doc """
  Handles a `DELETED` event
  """
  @spec delete(map()) :: :ok | :error
  @impl Bonny.Controller
  def delete(%{} = payload) do
    Logger.info("🚮 Deleted CR")

    with conn <- Bonny.Config.conn(),
         deploy_op <- K8s.Client.delete(gen_deployment(payload)),
         {:ok, _res} <- K8s.Client.run(conn, deploy_op) do
      Logger.info("🚮 Deleted Deployment")
      :ok
    else
      {:error, msg} = error ->
        Logger.error("Error: #{inspect(msg)}")
        error
    end
  end

  @doc """
  Called periodically for each existing CustomResource to allow for reconciliation.
  """
  @spec reconcile(map()) :: :ok | :error
  @impl Bonny.Controller
  def reconcile(%{} = payload) do
    Logger.info("🔴 Reconcile !")

    %{"metadata" => %{"name" => name}} = payload

    case get_deployment(payload) do
      {:ok, found} ->
        scale_deployment(payload, found)
        update_pod_status(payload)

      {:error, _error} ->
        Logger.info("ℹ️ Deployment #{name} not found, deploying !")
        deploy(payload)
    end

    :ok
  end

  defp deploy(payload) when is_map(payload) do
    with conn <- Bonny.Config.conn(),
         deploy_op <- K8s.Client.create(gen_deployment(payload)),
         {:ok, _res} <- K8s.Client.run(conn, deploy_op) do
      Logger.info("✅ Created Memcached deployment")
      :ok
    else
      {:error, _} = error ->
        Logger.error("Error: #{inspect(error)}")
        error
    end
  end

  defp scale_deployment(cr, deployment) do
    %{"spec" => %{"replicas" => size}} = deployment
    %{"spec" => %{"size" => expected_size}} = cr

    if size != expected_size do
      Logger.debug("Expected size #{inspect(expected_size)} got #{inspect(size)}")

      deployment
      |> put_in(["spec", "replicas"], expected_size)
      |> update_deployment()
    end
  end

  defp update_deployment(deployment) when is_map(deployment) do
    with conn <- Bonny.Config.conn(),
         update_op <- K8s.Client.update(deployment),
         {:ok, _} <- K8s.Client.run(conn, update_op) do
      :ok
    end
  end

  defp update_pod_status(payload) do
    with {:ok, memcached} <- get_resource(payload),
         {:ok, pods} <- get_pods(memcached),
         pod_names <- extract_pod_names(pods),
         %{"status" => %{"nodes" => status_nodes}} <- memcached,
         status_equal? when status_equal? == false <-
           Enum.sort(status_nodes) == Enum.sort(pod_names),
         {:ok, _res} <- update_status(memcached, %{"nodes" => pod_names}) do
      Logger.debug(
        "ℹ️ Updated status. Old list: #{inspect(status_nodes)}. New list: #{inspect(pod_names)}"
      )

      :ok
    end
  end

  defp get_deployment(payload) when is_map(payload) do
    %{"metadata" => %{"name" => name, "namespace" => namespace}} = payload

    get_deployment_op =
      K8s.Client.get("apps/v1", "Deployment", namespace: namespace, name: name)
      |> K8s.Selector.label({"app", "memcached"})
      |> K8s.Selector.label({"memcached_cr", name})

    with conn <- Bonny.Config.conn(),
         {:ok, memcached} <- K8s.Client.run(conn, get_deployment_op) do
      {:ok, memcached}
    else
      {:error, _} = error ->
        Logger.error("No Memcached resource found")
        error
    end
  end

  defp get_resource(payload) when is_map(payload) do
    %{"apiVersion" => api_version, "kind" => kind, "metadata" => metadata} = payload
    %{"name" => name, "namespace" => namespace} = metadata

    with conn <- Bonny.Config.conn(),
         get_op <- K8s.Client.get(api_version, kind, namespace: namespace, name: name),
         {:ok, memcached} <- K8s.Client.run(conn, get_op) do
      {:ok, memcached}
    else
      {:error, _} = error ->
        Logger.error("No Memcached resource found")
        error
    end
  end

  defp get_pods(payload) when is_map(payload) do
    %{"metadata" => %{"name" => name, "namespace" => namespace}} = payload

    conn = Bonny.Config.conn()

    list_pods_op =
      K8s.Client.list("v1", "Pod", namespace: namespace)
      |> K8s.Selector.label({"app", "memcached"})
      |> K8s.Selector.label({"memcached_cr", name})

    K8s.Client.run(conn, list_pods_op)
  end

  defp extract_pod_names(pods) do
    pods
    |> Map.get("items", [])
    |> Enum.map(&get_in(&1, ["metadata", "name"]))
  end

  defp update_status(memcached, status) do
    %{"apiVersion" => api_version, "metadata" => metadata} = memcached
    %{"name" => name, "namespace" => namespace} = metadata

    status_op =
      K8s.Client.update(
        api_version,
        "memcached/status",
        [namespace: namespace, name: name],
        Map.merge(memcached, %{"status" => status})
      )

    conn = Bonny.Config.conn()
    K8s.Client.run(conn, status_op)
  end

  defp gen_deployment(%{"metadata" => metadata, "spec" => spec}) do
    %{"name" => name, "namespace" => namespace} = metadata
    %{"size" => size} = spec

    ls = %{"app" => "memcached", "memcached_cr" => name}

    K8s.Resource.build("apps/v1", "Deployment", namespace, name)
    |> Map.merge(%{
      "spec" => %{
        "replicas" => size,
        "selector" => %{
          "matchLabels" => ls
        },
        "template" => %{
          "metadata" => %{
            "labels" => ls
          },
          "spec" => %{
            "containers" => [
              %{
                "image" => "memcached:1.4.36-alpine",
                "name" => "memcached",
                "command" => ["memcached", "-m=64", "-o", "modern", "-v"],
                "ports" => [%{"containerPort" => 11_211, "name" => "memcached"}]
              }
            ]
          }
        }
      }
    })
  end
end
