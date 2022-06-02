import Config

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :file, :line]

config :bonny,
  controllers: [
    MemcachedOperatorBonny.Controller.V1.Memcached
  ],
  get_conn: {K8s.Conn, :from_file, ["~/.kube/config", [context: "minikube"]]},
  group: "cache.driffaud.fr",
  operator_name: "memcached-operator",
  api_version: "apiextensions.k8s.io/v1",
  reconcile_every: 5

import_config("#{config_env()}.exs")
