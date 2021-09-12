# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

# Enable the Nerves integration with Mix
Application.start(:nerves_bootstrap)

config :raft,
  target: Mix.target(),
  # peers: [
  #   :"nerves-9ef5@nerves-9ef5.local",
  #   :"nerves-9c9e@nerves-9c9e.local",
  #   :"nerves-9398@nerves-9398.local"
  # ],
  # peers: [
  #   :"nerves-9398@nerves-9398.local",
  #   :"nerves-2be4@nerves-2be4.local",
  #   :"nerves-9ef5@nerves-9ef5.local",
  #   :"nerves-9c9e@nerves-9c9e.local",
  #   :"nerves-fa27@nerves-fa27.local"
  # ],
  peers: [
    :"nerves-9398@nerves-9398.local",
    :"nerves-2be4@nerves-2be4.local",
    :"nerves-9ef5@nerves-9ef5.local",
    :"nerves-9c9e@nerves-9c9e.local",
    :"nerves-fa27@nerves-fa27.local",
    :"nerves-1152@nerves-1152.local",
    :"nerves-4e22@nerves-4e22.local"
  ],
  min_election_timeout: 500,
  max_election_timeout: 800,
  heartbeat_timeout: 250,
  cookie: :secret

# Customize non-Elixir parts of the firmware. See
# https://hexdocs.pm/nerves/advanced-configuration.html for details.

config :nerves, :firmware, rootfs_overlay: "rootfs_overlay"

# Set the SOURCE_DATE_EPOCH date for reproducible builds.
# See https://reproducible-builds.org/docs/source-date-epoch/ for more information

config :nerves, source_date_epoch: "1630878789"

# Use Ringlogger as the logger backend and remove :console.
# See https://hexdocs.pm/ring_logger/readme.html for more information on
# configuring ring_logger.

# config :logger,
#   compile_time_purge_matching: [
#     [level_lower_than: :debug]
#   ],
#   backends: [:console, {RingLogger, :debug_log}],
#   format: {Raft.LogFormatter, :format},
#   metadata: [:node]

config :logger, backends: [RingLogger]

config :ring_logger,
  application_levels: %{raft: :info},
  color: [info: :yellow]

# config :logger, RingLogger, max_size: 5000

# config :logger, :console, level: :info

# config :logger, :debug_log,
#   level: :debug,
#   format: {Raft.LogFormatter, :format},
#   metadata: [:node, :mfa]

config :mdns_lite,
  dns_bridge_enabled: true,
  dns_bridge_ip: {127, 0, 0, 53},
  dns_bridge_port: 53,
  dns_bridge_recursive: true

config :vintage_net,
  additional_name_servers: [{127, 0, 0, 53}]

if Mix.target() == :host or Mix.target() == :"" do
  import_config "host.exs"
else
  import_config "target.exs"
end
