import Config

case config_env() do
  :prod ->
    config :logger, level: :info

  _ ->
    nil
end

config :logger, :default_formatter,
  format: "\n$time [$level] $message $metadata\n",
  metadata: [:mfa, :pid, :registered_name]
