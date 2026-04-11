defmodule MiniSymphony.Tools.FileReadTest do
  use ExUnit.Case, async: true
  doctest MiniSymphony.Tools.FileRead

  @moduletag :tmp_dir

  describe "read_file/2" do
    test "files can be read", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "hello.txt")
      File.write!(path, "file content here")

      # Now run your tool
      assert {:ok, content} = MiniSymphony.Tools.FileRead.read_file("hello.txt", tmp_dir)
      assert String.contains?(content, "file content here")
    end

    test "non existent file returns error", %{tmp_dir: tmp_dir} do
      assert {:error, message} = MiniSymphony.Tools.FileRead.read_file("hello.txt", tmp_dir)
      assert String.contains?(message, "Could not read file: enoent")
    end

    test "path outside of workspace throws error", %{tmp_dir: tmp_dir} do
      malicious_path = "../../etc/passwd"

      result = MiniSymphony.Tools.FileRead.read_file(malicious_path, tmp_dir)

      assert {:error, "Access Denied: Path is outside workspace."} = result
    end
  end

  describe "tool_definition/0" do
    test "returns a valid Ollama/OpenAI schema" do
      schema = MiniSymphony.Tools.FileRead.tool_definition()

      assert schema.type == "function"
      assert schema.function.name == "read_file"

      assert get_in(schema, [:function, :parameters, :properties, :path, :type]) == "string"

      assert "path" in schema.function.parameters.required
    end
  end
end
