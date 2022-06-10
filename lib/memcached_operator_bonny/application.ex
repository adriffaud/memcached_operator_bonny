defmodule MemcachedOperatorBonny.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Bonny.ControllerSupervisor, controller: MemcachedOperatorBonny.Controller.V1.Memcached}
    ]

    opts = [strategy: :one_for_one, name: MemcachedOperatorBonny.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
