defmodule MiniSymphony.Tools.FileRead do
  @max_lines 500

  def read_file(path, workspace_path) do
    workspace_path = Path.expand(workspace_path) |> Path.absname()
    full_path = Path.expand(path, workspace_path) |> Path.absname()

    if String.starts_with?(full_path, workspace_path) do
      if File.dir?(full_path) do
        {:ok, %{output: "Error: '#{path}' is a directory. Use a directory listing tool instead."}}
      else
        case File.read(full_path) do
          {:ok, content} -> {:ok, %{output: format_content(content)}}
          {:error, reason} -> {:ok, %{output: "Error: Could not read file: #{reason}"}}
        end
      end
    else
      {:error, %{output: "Access Denied: Path '#{path}' is outside workspace."}}
    end
  end

  @doc "Returns the tool definition for Ollama's tool use format."
  def tool_definition do
    %{
      type: "function",
      function: %{
        name: "read_file",
        description:
          "Read a file in the workspace directory. Use this for all file read operations",
        parameters: %{
          type: "object",
          required: ["path"],
          properties: %{
            path: %{
              type: "string",
              description: "the path of the file to read - relative to the workspace"
            }
          }
        }
      }
    }
  end

  defp format_content(content) do
    content
    |> String.split("\n")
    |> Enum.take(@max_lines)
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {line, i} -> "#{i} | #{line}" end)
  end
end
