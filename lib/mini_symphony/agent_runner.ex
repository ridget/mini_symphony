defmodule MiniSymphony.AgentRunner do
  alias MiniSymphony.{Tools.Shell, Tools.FileRead, Tools.FileWrite, Workspace}
  require Logger

  def run(issue, config) do
    max_turns = Map.get(config, :max_turns, 10)

    with {:ok, workspace} <- Workspace.create_for_issue(config.workspace_root, issue) do
      messages = [
        %{role: "system", content: system_prompt(workspace)},
        %{role: "user", content: user_prompt(issue)}
      ]

      run_turns(messages, workspace, config, 0, max_turns, issue)
    end
  end

  defp system_prompt(workspace) do
    """
      You are an autonomous developer agent.
      Workspace Root (Relative base): #{workspace}

      ## RULES
      1. RELATIVE PATHS ONLY: Never use absolute paths (e.g., /tmp/... or /README). All paths are relative to the workspace root.
      2. ONE ACTION PER TURN: Provide exactly one tool call per message. Do not provide next steps or continuations.
      3. NO PLACEHOLDERS: Do not write files with "[...]" or "insert content." You must have the data before you write.
      4. VERIFY: After `shell_execute` or `write_file`, you must use a tool in the next turn to verify the result (e.g., `ls` or `read_file`).
      5. PROTOCOL: Reasoning first (1 sentence), then the tool call.

      ## CURRENT STATE
      The workspace is currently empty or at the state described in the history. You must execute the tools to make progress.
    """
  end

  defp user_prompt(issue) do
    """
    Issue: #{issue.title}

    #{issue.description}
    """
  end

  defp run_turns(_messages, _workspace, _config, turn, max_turns, _issue)
       when turn >= max_turns do
    {:error, :max_turns_exceeded}
  end

  defp run_turns(messages, workspace, config, turn, max_turns, issue) do
    tools = [Shell.tool_definition(), FileRead.tool_definition(), FileWrite.tool_definition()]

    case config.llm_module.chat(config.ollama_url, config.model, messages, tools: tools) do
      {:ok, %{"tool_calls" => [_ | _] = tool_calls} = assistant_msg} ->
        tool_results = execute_tool_calls(workspace, tool_calls)
        updated_messages = messages ++ [assistant_msg | tool_results]
        run_turns(updated_messages, workspace, config, turn + 1, max_turns, issue)

      {:ok, %{"content" => content} = assistant_msg} ->
        Logger.info(
          "issue: #{issue.id} content is #{content}, assistant_msg: #{inspect(assistant_msg)}"
        )

        case try_extract_tool_calls(content) do
          {:ok, extracted_calls} ->
            tool_results = execute_tool_calls(workspace, extracted_calls)

            run_turns(
              messages ++ [assistant_msg | tool_results],
              workspace,
              config,
              turn + 1,
              max_turns,
              issue
            )

          :error ->
            continuation_msg = %{
              role: "user",
              content:
                "I could not parse a tool call from your last message. Ensure you provide exactly one JSON object containing 'name' and 'parameters'. Do not use placeholders like [insert content]."
            }

            run_turns(
              messages ++ [assistant_msg, continuation_msg],
              workspace,
              config,
              turn + 1,
              max_turns,
              issue
            )
        end

        case config.fetch_issue_fn.(issue.id) do
          {:ok, %{state: current_state}} when current_state in ["todo", "processing"] ->
            Logger.info("Agent claims done but #{issue.id} is still #{current_state}. Nudging...")

            continuation_msg = %{
              role: "user",
              content: """
              - The previous turn completed normally, but the issue is still in an active state.
              - This is continuation turn 
              - Resume from the current workspace and state instead of restarting from scratch.
              - The original issue instructions and prior turn context are already present in this thread, so do not restate them before acting.
              - Focus on the remaining ticket work and do not end the turn while the issue stays active unless you are truly blocked.
              """
            }

            run_turns(
              messages ++ [assistant_msg, continuation_msg],
              workspace,
              config,
              turn + 1,
              max_turns,
              issue
            )

          {:ok, %{state: "done"}} ->
            Logger.info("Agent confirmed issue #{issue.id} is done.")
            :ok

          {:ok, %{state: "failed"}} ->
            {:error, :task_failed}

          {:error, reason} ->
            Logger.warning("Could not verify state: #{inspect(reason)}")
            :ok
        end

      {:error, reason} ->
        MiniSymphony.IssueSource.Yaml.update_state(config.issues_file, issue.id, "failed")
        {:error, reason}
    end
  end

  defp execute_tool_calls(workspace, tool_calls) do
    Enum.map(tool_calls, fn tool_call ->
      %{"function" => %{"arguments" => args, "name" => name}, "id" => id} = tool_call

      result =
        case name do
          "shell_execute" -> Shell.execute(args["cmd"], workspace)
          "read_file" -> FileRead.read_file(args["path"], workspace)
          "write_file" -> FileWrite.execute(args["path"], args["content"], workspace)
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

  defp try_extract_tool_calls(content) do
    # Find all { ... } blocks
    Regex.scan(~r/\{[\s\S]*?\}/, content)
    |> List.flatten()
    |> Enum.find_value(:error, fn json_str ->
      case Jason.decode(json_str) do
        {:ok, %{"name" => name} = call} ->
          args = call["parameters"] || call["arguments"] || %{}

          {:ok,
           [
             %{
               "function" => %{"name" => name, "arguments" => args},
               "id" => "manual_#{System.unique_integer([:positive])}"
             }
           ]}

        _ ->
          nil
      end
    end)
  end
end
