defmodule MemcachedOperatorBonny.Config do
  @moduledoc false

  @doc """
  `K8s.Conn` name used for this operator.
  """
  @spec conn() :: K8s.Conn.t()
  def conn() do
    get_conn = Application.get_env(:memcached_operator_bonny, :conn)

    case apply_get_conn(get_conn) do
      {:ok, %K8s.Conn{} = conn} ->
        conn

      %K8s.Conn{} = conn ->
        conn

      _ ->
        raise("""
        Check bonny.get_conn in your config.exs. get_conn must be a tuple in the form {Module, :function, [args]}
        which defines a function returning {:ok, K8s.Conn.t()}. Given: #{inspect(get_conn)}
        """)
    end
  end

  defp apply_get_conn({module, function, args}), do: apply(module, function, args)
  defp apply_get_conn({module, function}), do: apply(module, function, [])
  defp apply_get_conn(_), do: :error
end
