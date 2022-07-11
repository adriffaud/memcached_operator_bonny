defmodule MemcachedOperatorBonny.Application do
  @moduledoc false
  use Application

  alias MemcachedOperatorBonny.RunnerSupervisor

  @impl true
  def start(_type, _args) do
    config = %{
      operator_group: "cache.example.com",
      operator_name: "memcached-operator",
      controllers: [
        %{
          crd_kind: "Memcached",
          crd_version: "v1",
          dependents: [
            %{dependent_api_version: "apps/v1", dependent_kind: "Deployment"}
          ],
          reconciler: MemcachedOperatorBonny.Controller.V1.Memcached
        }
      ]
    }

    children = [
      {DynamicSupervisor, name: RunnerSupervisor, strategy: :one_for_one},
      {MemcachedOperatorBonny.Operator, config}
    ]

    opts = [strategy: :one_for_one, name: MemcachedOperatorBonny.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
