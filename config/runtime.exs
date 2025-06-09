import Config

case config_env() do
  :prod ->
    config :logger, level: :info

  _ ->
    nil
end
