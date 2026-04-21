defmodule MiniSymphony.OrchestratorTest do
  use ExUnit.Case, async: false
  alias MiniSymphony.Llm.NoOp
  alias MiniSymphony.Orchestrator

  setup do
    tmp_dir = System.tmp_dir!()
    path = Path.join(tmp_dir, "test_issues.yaml")
    File.write!(path, Ymlr.document!([]))
    on_exit(fn -> File.rm(path) end)
    %{issues_file: path, tmp_dir: tmp_dir}
  end

  test "dispatches an issue when it finds a todo in the YAML", %{
    issues_file: path,
    tmp_dir: tmp_dir
  } do
    issue = %{id: "issue_id", title: "Issue 1", state: "todo", identifier: "I-1", priority: 1}
    File.write!(path, Ymlr.document!([issue]))

    config = %{
      workspace_root: tmp_dir,
      issues_file: path,
      poll_interval_ms: 1000,
      max_concurrent_agents: 2,
      ollama_url: "http://stub",
      llm_module: NoOp,
      model: "test",
      fetch_issue_fn: fn _id -> {:ok, issue} end
    }

    Process.put(:stub_responses, [
      {:ok, %{"role" => "assistant", "content" => "I think I finished the work!"}},
      {:ok, %{"role" => "assistant", "content" => "Ah, my apologies. Now it is truly done."}}
    ])

    {:ok, pid} = Orchestrator.start_link(config: config, name: nil)

    send(pid, {:tick, :any_token_will_do_if_not_validated})

    wait_until(fn ->
      state = :sys.get_state(pid)
      MapSet.member?(state.claimed, "issue_id")
    end)

    state = :sys.get_state(pid)
    assert MapSet.member?(state.claimed, "issue_id")
    assert map_size(state.running) == 1
  end

  defp wait_until(fun) do
    if fun.() do
      :ok
    else
      Process.sleep(10)
      wait_until(fun)
    end
  end
end
