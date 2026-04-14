defmodule MiniSymphony.AgentRunnerTest do
  # using process dictionary
  use ExUnit.Case, async: false

  alias MiniSymphony.AgentRunner

  setup do
    workspace_root =
      Path.join(System.tmp_dir!(), "agent_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(workspace_root)
    on_exit(fn -> File.rm_rf!(workspace_root) end)
    %{workspace_root: workspace_root}
  end

  defp config(root, overrides \\ []) do
    Map.merge(
      %{
        ollama_url: "http://stub",
        model: "test",
        workspace_root: root,
        max_turns: 5,
        llm_module: MiniSymphony.Llm.NoOp
      },
      Map.new(overrides)
    )
  end

  test "completes in one turn when model returns content only", %{workspace_root: root} do
    Process.put(:stub_responses, [
      {:ok, %{"role" => "assistant", "content" => "Done!"}}
    ])

    task = %MiniSymphony.Issue{id: "t1", identifier: "TEST-1", title: "Test", state: "todo"}
    assert :ok = AgentRunner.run(task, config(root))
  end

  test "executes tool calls and feeds results back", %{workspace_root: root} do
    Process.put(:stub_responses, [
      {:ok,
       %{
         "role" => "assistant",
         "content" => "",
         "tool_calls" => [
           %{
             "function" => %{
               "name" => "shell_execute",
               "arguments" => %{"command" => "echo hello"}
             },
             "id" => "callabc123"
           }
         ]
       }},
      {:ok, %{"role" => "assistant", "content" => "All done."}}
    ])

    task = %MiniSymphony.Issue{id: "t1", identifier: "TEST-1", title: "Test", state: "todo"}
    assert :ok = AgentRunner.run(task, config(root))
  end

  test "returns error when max turns exceeded", %{workspace_root: root} do
    # Stub always returns tool calls — agent never finishes
    always_tool_call =
      {:ok,
       %{
         "role" => "assistant",
         "content" => "",
         "tool_calls" => [
           %{
             "function" => %{
               "name" => "shell_execute",
               "arguments" => %{"command" => "echo loop"}
             },
             "id" => "callabc123"
           }
         ]
       }}

    Process.put(:stub_responses, List.duplicate(always_tool_call, 10))
    task = %MiniSymphony.Issue{id: "t1", identifier: "TEST-1", title: "Test", state: "todo"}
    assert {:error, :max_turns_exceeded} = AgentRunner.run(task, config(root, max_turns: 2))
  end
end
