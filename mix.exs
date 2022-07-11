defmodule MemcachedOperatorBonny.MixProject do
  use Mix.Project

  def project do
    [
      app: :memcached_operator_bonny,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {MemcachedOperatorBonny.Application, []}
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:test, :dev], runtime: false},
      {:k8s, path: "/home/adrien/dev/k8s"}
    ]
  end
end
