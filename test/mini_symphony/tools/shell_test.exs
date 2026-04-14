defmodule MiniSymphony.Tools.ShellTest do
  use ExUnit.Case, async: true
  doctest MiniSymphony.Tools.Shell
  alias MiniSymphony.Tools.Shell

  @moduletag :tmp_dir

  describe "execute/3" do
    test "commands can be executed", %{tmp_dir: tmp_dir} do
      result = Shell.execute("echo hello", tmp_dir)

      assert {:ok, %{exit_code: 0, output: "hello\n"}} = result
    end

    test "bad commands return non-zero exit code", %{tmp_dir: tmp_dir} do
      result = Shell.execute("exho hello", tmp_dir)
      assert {:ok, %{exit_code: 127, output: _output}} = result
    end

    test "long output is truncated", %{tmp_dir: tmp_dir} do
      {:ok, %{exit_code: 0, output: output}} =
        Shell.execute("seq 1 10000", tmp_dir)

      assert !String.contains?(output, "10000")
    end

    test "command runs in directory", %{tmp_dir: tmp_dir} do
      Shell.execute("touch hello.txt", tmp_dir)

      {:ok, files} = File.ls(tmp_dir)

      assert "hello.txt" in files
    end
  end

  describe "tool_definition/0" do
    test "returns a valid Ollama/OpenAI schema" do
      schema = Shell.tool_definition()

      assert schema.type == "function"
      assert schema.function.name == "shell_execute"

      assert get_in(schema, [:function, :parameters, :properties, :command, :type]) == "string"

      assert "command" in schema.function.parameters.required
    end
  end
end
