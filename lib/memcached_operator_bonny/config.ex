defmodule MemcachedOperatorBonny.Config do
  @moduledoc false

  @doc """
  `K8s.Conn` name used for this operator.
  """
  @spec conn() :: K8s.Conn.t()
  def conn() do
    get_conn = Application.get_env(:bonny, :get_conn)

    case apply_get_conn(get_conn) do
      {:ok, %K8s.Conn{} = conn} ->
        conn

      %K8s.Conn{} = conn ->
        conn

      error ->
        raise(error)

        error
    end
  end

  defp apply_get_conn({module, function, args}), do: apply(module, function, args)
  defp apply_get_conn({module, function}), do: apply(module, function, [])
  defp apply_get_conn(_), do: :error
end
