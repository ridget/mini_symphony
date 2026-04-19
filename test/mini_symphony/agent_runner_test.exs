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

  defp config(root, overrides) do
    Map.merge(
      %{
        ollama_url: "http://stub",
        model: "test",
        workspace_root: root,
        max_turns: 5,
        llm_module: MiniSymphony.Llm.NoOp,
        issues_file: "issues.yaml",
        fetch_issue_fn: nil
      },
      Map.new(overrides)
    )
  end

  test "completes in one turn when model returns content only", %{workspace_root: root} do
    Process.put(:stub_responses, [
      {:ok, %{"role" => "assistant", "content" => "Done!"}}
    ])

    issue = %MiniSymphony.Issue{id: "t1", identifier: "TEST-1", title: "Test", state: "todo"}

    assert :ok =
             AgentRunner.run(
               issue,
               config(root, fetch_issue_fn: fn _id -> {:ok, %{issue | state: "done"}} end)
             )
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
               "arguments" => %{"cmd" => "echo hello"}
             },
             "id" => "callabc123"
           }
         ]
       }},
      {:ok, %{"role" => "assistant", "content" => "All done."}}
    ])

    issue = %MiniSymphony.Issue{id: "t1", identifier: "TEST-1", title: "Test", state: "todo"}

    assert :ok =
             AgentRunner.run(
               issue,
               config(root, fetch_issue_fn: fn _id -> {:ok, %{issue | state: "done"}} end)
             )
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
               "arguments" => %{"cmd" => "echo loop"}
             },
             "id" => "callabc123"
           }
         ]
       }}

    Process.put(:stub_responses, List.duplicate(always_tool_call, 10))
    issue = %MiniSymphony.Issue{id: "t1", identifier: "TEST-1", title: "Test", state: "todo"}
    assert {:error, :max_turns_exceeded} = AgentRunner.run(issue, config(root, max_turns: 2))
  end

  test "nudges the agent if it returns text but the state is still active", %{
    workspace_root: root
  } do
    Process.put(:stub_responses, [
      {:ok, %{"role" => "assistant", "content" => "I think I finished the work!"}},
      {:ok, %{"role" => "assistant", "content" => "Ah, my apologies. Now it is truly done."}}
    ])

    issue = %MiniSymphony.Issue{
      id: "nudge-me",
      identifier: "TEST-2",
      title: "nudge me",
      state: "todo"
    }

    fetch_fn = fn id ->
      case Process.get({:fetch_count, id}, 0) do
        0 ->
          Process.put({:fetch_count, id}, 1)
          {:ok, %{issue | state: "todo"}}

        _ ->
          {:ok, %{issue | state: "done"}}
      end
    end

    conf = config(root, fetch_issue_fn: fetch_fn, max_turns: 3)

    assert :ok = AgentRunner.run(issue, conf)
  end
end
