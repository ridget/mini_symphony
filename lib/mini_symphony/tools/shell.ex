defmodule MiniSymphony.Tools.Shell do
  @max_output_bytes 4096

  def execute(cmd, workspace) when is_list(cmd) do
    execute(Enum.join(cmd, " "), workspace)
  end

  def execute(command, workspace_path, opts \\ []) do
    safe_path = to_string(workspace_path || ".")

    # hack to ensure commands executed relative to safe path
    safe_command =
      command
      |> to_string()
      |> String.replace(~r/cd\s+\.\.\/?/, "ls")

    timeout = Keyword.get(opts, :timeout, 60_000)

    task =
      Task.async(fn ->
        System.cmd("sh", ["-c", safe_command],
          cd: safe_path,
          stderr_to_stdout: true,
          env: [{"HOME", safe_path}, {"SSH_AUTH_SOCK", System.get_env("SSH_AUTH_SOCK")}]
        )
      end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, {output, code}} ->
        {:ok, %{output: truncate(output), exit_code: code, timed_out: false}}

      _ ->
        {:ok,
         %{
           output: "Command failed to complete within #{timeout}ms.",
           exit_code: 124,
           timed_out: true
         }}
    end
  end

  @doc "Returns the tool definition for Ollama's tool use format."
  def tool_definition do
    %{
      type: "function",
      function: %{
        name: "shell_execute",
        description:
          "Run a shell command in the workspace directory. Use this for the following file operations — creating, listing, and modifying files.",
        parameters: %{
          type: "object",
          required: ["cmd"],
          properties: %{
            cmd: %{
              type: "string",
              description: "The shell cmd to execute"
            }
          }
        }
      }
    }
  end

  defp truncate(output) do
    if String.length(output) > @max_output_bytes do
      String.slice(output, 0, @max_output_bytes)
    else
      output
    end
  end
end
