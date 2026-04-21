defmodule MiniSymphony.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    config = %MiniSymphony.Config{
      issues_file: System.get_env("ISSUES_FILE", "issues.yaml"),
      model: System.get_env("OLLAMA_MODEL", "llama3.1:8b")
    }

    children = [{Task.Supervisor, name: MiniSymphony.TaskSupervisor}]

    children =
      if Mix.env() == :test do
        children
      else
        children ++ [{MiniSymphony.Orchestrator, config: config}]
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: MiniSymphony.Supervisor)
  end
end
