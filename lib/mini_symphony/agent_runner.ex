defmodule MiniSymphony.AgentRunner do
  alias MiniSymphony.{Llm.Ollama, Tools.Shell, Workspace}

  def run(issue, config) do
    with {:ok, workspace} <- Workspace.create_for_issue(config.workspace_root, issue) do
      messages = [
        %{role: "system", content: system_prompt(workspace)},
        %{role: "user", content: user_prompt(issue)}
      ]

      case Ollama.chat(config.ollama_url, config.model, messages) do
        {:ok, %{"content" => content}} ->
          IO.puts("Agent response: #{content}")
          :ok

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp system_prompt(workspace) do
    """
    You are a coding agent working in the directory: #{workspace}
    You have a shell_execute tool to run commands in this directory.
    You have a file_read tool to read files in this directory.
    Complete the issue described by the user. Be concise.
    """
  end

  defp user_prompt(issue) do
    """
    Issue: #{issue.title}

    #{issue.description}
    """
  end
end
