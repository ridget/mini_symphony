defmodule MiniSymphony.Config do
  config :logger, :console,
    format: "$time [$level] $metadata $message
",
    metadata: [:task_id, :task_identifier]
end
