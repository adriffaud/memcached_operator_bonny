import Config

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :file, :line]

config :bonny,
  get_conn: {K8s.Conn, :from_file, ["~/.kube/config", [context: "minikube"]]},
  group: "cache.driffaud.fr",
  operator_name: "memcached-operator",
  api_version: "apiextensions.k8s.io/v1",
  # Will only watch its own namespace if not specified, unlike specified in the docs
  namespace: ""

import_config("#{config_env()}.exs")
