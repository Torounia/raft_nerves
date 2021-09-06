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
  peers: [:"peer@nerves-9ef5.local", :"peer@nerves-9c9e.local", :"peer@nerves-9398.local"],
  min_election_timeout: 800,
  max_election_timeout: 1100,
  heartbeat_timeout: 500,
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

# config :logger, RingLogger, max_size: 5000

# config :logger, :console, level: :info

# config :logger, :debug_log,
#   level: :debug,
#   format: {Raft.LogFormatter, :format},
#   metadata: [:node, :mfa]

if Mix.target() == :host or Mix.target() == :"" do
  import_config "host.exs"
else
  import_config "target.exs"
end