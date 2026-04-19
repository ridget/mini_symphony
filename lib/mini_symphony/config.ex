defmodule MiniSymphony.Config do
  defstruct issues_file: "issues.yaml",
            poll_interval_ms: 1000,
            max_concurrent_agents: 2,
            workspace_root: "/tmp/mini_symphony_workspaces",
            ollama_url: "http://localhost:11434",
            llm_module: MiniSymphony.Llm.Ollama,
            model: "llama3.1:8b",
            max_turns: 10,
            # setup in orchestrator init
            fetch_issue_fn: nil,
            retry_attempts: %{}
end
