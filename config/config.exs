import Config

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :file, :line]

config :memcached_operator_bonny,
  conn: {K8s.Conn, :from_file, ["~/.kube/config", [context: "minikube"]]}

import_config("#{config_env()}.exs")
