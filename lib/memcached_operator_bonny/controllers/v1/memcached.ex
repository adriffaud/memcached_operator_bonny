defmodule MemcachedOperatorBonny.Controller.V1.Memcached do
  @moduledoc false
  use Bonny.Controller
  require Logger

  @scope :namespaced
  @names %{
    plural: "memcached",
    singular: "memcached",
    kind: "Memcached",
    shortNames: []
  }

  @rule {"apps", ["deployments"], ["*"]}
  @rule {"", ["pods"], ["*"]}

  @doc """
  Handles an `ADDED` event
  """
  @spec add(map()) :: :ok | :error
  @impl Bonny.Controller
  def add(%{} = payload) do
    Logger.info("➕ Added CR")

    %{"apiVersion" => api_version, "kind" => kind, "metadata" => metadata} = payload
    %{"name" => name, "namespace" => namespace} = metadata

    conn = Bonny.Config.conn()

    # GET MEMCACHED CR
    get_op = K8s.Client.get(api_version, kind, namespace: namespace, name: name)
    {:ok, _memcached} = K8s.Client.run(conn, get_op)

    # CREATE DEPLOYMENT
    deploy_op = K8s.Client.create(gen_deployment(payload))
    {:ok, _res} = K8s.Client.run(conn, deploy_op)
    Logger.info("Created Memcached deployment")

    # LIST PODS
    list_pods_op =
      K8s.Client.list("v1", "Pod", namespace: namespace)
      |> K8s.Selector.label({"app", "memcached"})
      |> K8s.Selector.label({"memcached_cr", name})

    {:ok, pods} = K8s.Client.run(conn, list_pods_op)

    pods
    |> Map.get("items", [])
    |> Enum.map(&get_in(&1, ["metadata", "name"]))
    |> IO.inspect(label: :pod_names)

    :ok

    # status_op =
    #   K8s.Client.update(api_version, kind, [namespace: namespace, name: name], %{
    #     "status" => %{"nodes" => pod_names}
    #   })

    # IO.inspect(status_op)

    # with conn <- Bonny.Config.conn(),
    #      deploy_op <- K8s.Client.create(gen_deployment(payload)),
    #      {:ok, _res} <- K8s.Client.run(conn, deploy_op) do
    #   Logger.info("Created memcached resource")
    #   :ok
    # else
    #   {:error, _} = error ->
    #     Logger.error("Error: #{inspect(error)}")
    #     error
    # end
  end

  @doc """
  Handles a `MODIFIED` event
  """
  @spec modify(map()) :: :ok | :error
  @impl Bonny.Controller
  def modify(%{} = payload) do
    Logger.info("⏳ UPDATE")
    Logger.debug(inspect(payload))
    :ok
  end

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
    Logger.debug(inspect(payload))
    :ok
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
