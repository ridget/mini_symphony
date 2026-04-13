defmodule MiniSymphony.AgentRunner do
  alias MiniSymphony.{Llm.Ollama, Tools.Shell, Tools.FileRead, Workspace}

  def run(issue, config) do
    max_turns = Map.get(config, :max_turns, 10)

    with {:ok, workspace} <- Workspace.create_for_issue(config.workspace_root, issue) do
      messages = [
        %{role: "system", content: system_prompt(workspace)},
        %{role: "user", content: user_prompt(issue)}
      ]

      run_turns(messages, workspace, config, 0, max_turns)
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

  defp run_turns(_messages, _workspace, _config, turn, max_turns)
       when turn >= max_turns do
    {:error, :max_turns_exceeded}
  end

  defp run_turns(messages, workspace, config, turn, max_turns) do
    tools = [Shell.tool_definition(), FileRead.tool_definition()]

    case Ollama.chat(config.ollama_url, config.model, messages, tools: tools) do
      {:ok, %{"tool_calls" => [_ | _] = tool_calls} = assistant_msg} ->
        # Model wants to use tools
        tool_results = execute_tool_calls(workspace, tool_calls)
        updated_messages = messages ++ [assistant_msg | tool_results]
        run_turns(updated_messages, workspace, config, turn + 1, max_turns)

      {:ok, %{"content" => _content} = _assistant_msg} ->
        # Model responded with text — it's done
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_tool_calls(workspace, tool_calls) do
    Enum.map(tool_calls, fn tool_call ->
      %{"function" => %{"name" => name, "arguments" => args}, "id" => id} = tool_call

      result =
        case name do
          "shell_execute" -> Shell.execute(args["command"], workspace)
          "read_file" -> FileRead.read_file(args["path"], workspace)
          _ -> {:error, "Unknown tool"}
        end

      case result do
        {:ok, %{output: output, exit_code: code, timed_out: timed_out}} ->
          %{role: "tool", content: format_content(output, code, timed_out), tool_call_id: id}

        _ ->
          %{role: "tool", content: "Error: Tool failed", tool_call_id: id}
      end
    end)
  end

  defp format_content(output, exit_code, timed_out) do
    if timed_out do
      "Exit code: #{exit_code}\n Timed out \n #{output}"
    else
      "Exit code: #{exit_code}\n#{output}"
    end
  end
end
