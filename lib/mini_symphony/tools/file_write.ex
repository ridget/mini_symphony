defmodule MiniSymphony.Tools.FileWrite do
  def execute(path, content, workspace_path) do
    full_path = Path.expand(path, workspace_path)
    File.mkdir_p!(Path.dirname(full_path))

    case File.write(full_path, content) do
      :ok -> {:ok, %{output: "Successfully wrote to #{path}", exit_code: 0, timed_out: false}}
      {:error, reason} -> {:error, reason}
    end
  end

  def tool_definition do
    %{
      type: "function",
      function: %{
        name: "write_file",
        description: "Write or overwrite a file with specific content.",
        parameters: %{
          type: "object",
          required: ["path", "content"],
          properties: %{
            path: %{type: "string"},
            content: %{type: "string", description: "The full content of the file"}
          }
        }
      }
    }
  end
end
