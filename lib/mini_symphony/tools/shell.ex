defmodule MiniSymphony.Tools.Shell do
  @max_output_bytes 4096

  def execute(command, workspace_path, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)

    task =
      Task.async(fn ->
        System.cmd("sh", ["-c", command],
          cd: workspace_path,
          stderr_to_stdout: true,
          env: [{"HOME", workspace_path}]
        )
      end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, {output, code}} ->
        {:ok, %{output: truncate(output), exit_code: code, timed_out: false}}

      _ ->
        # Whether it timed out or the task crashed, we return a success 
        # tuple so the runner can easily report back to the LLM.
        {:ok,
         %{
           output: "Command failed to complete within #{timeout}ms.",
           # 124 is the standard 'timeout' exit code in bash
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
