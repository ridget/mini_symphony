defmodule MiniSymphony.WorkspaceTest do
  use ExUnit.Case, async: true
  doctest MiniSymphony.Workspace

  @moduletag :tmp_dir

  describe "create_for_issue/2" do
    setup do
      issue = %MiniSymphony.Issue{
        id: "t1",
        identifier: "TEST 1",
        title: "Active Issue",
        description: "Do Something",
        state: "todo",
        priority: 1
      }

      %{issue: issue}
    end

    test "workspace is created", %{tmp_dir: tmp_dir, issue: issue} do
      {:ok, path} = MiniSymphony.Workspace.create_for_issue(tmp_dir, issue)

      expected_path = Path.join(tmp_dir, "TEST-1")
      assert path == expected_path

      assert File.dir?(path), "The workspace directory was not actually created"
    end

    test "workspace is only created once per task", %{tmp_dir: tmp_dir, issue: issue} do
      {:ok, path} = MiniSymphony.Workspace.create_for_issue(tmp_dir, issue)

      expected_path = Path.join(tmp_dir, "TEST-1")
      assert path == expected_path

      {:ok, idempotent_path} = MiniSymphony.Workspace.create_for_issue(tmp_dir, issue)

      assert(path == idempotent_path)
    end
  end

  describe "remove/1" do
    test "deletes the directory", %{tmp_dir: tmp_dir} do
      path_to_delete = Path.join(tmp_dir, "TEST-1")
      File.mkdir_p!(path_to_delete)
      {:ok, [^path_to_delete]} = MiniSymphony.Workspace.remove(path_to_delete)

      refute File.exists?(path_to_delete)
    end
  end

  describe "cleanup_stale/2" do
    setup %{tmp_dir: tmp_dir} do
      issues = [
        %MiniSymphony.Issue{
          id: "issue-1",
          identifier: "ISSUE-1",
          title: "List files and summarise",
          description: """
          List all files in the current directory.
          Create a file called summary.txt that contains
          the file listing and a one-line description of
          each file's likely purpose.
          """,
          state: "todo",
          priority: 1
        },
        %MiniSymphony.Issue{
          id: "issue-2",
          identifier: "ISSUE-2",
          title: "Transform input data",
          description: """
          Read the file input.txt in the workspace.
          Reverse each line and write the result to output.txt.
          """,
          state: "todo",
          priority: 2
        },
        %MiniSymphony.Issue{
          id: "issue-3",
          identifier: "ISSUE-3",
          title: "Already done issue",
          description: "This issue is already complete.",
          state: "done",
          priority: 3
        }
      ]

      Enum.map(issues, &MiniSymphony.Workspace.create_for_issue(tmp_dir, &1))

      active_issues =
        Enum.filter(issues, fn issue -> issue.state in MiniSymphony.Issue.active_states() end)

      %{active_issues: active_issues}
    end

    test "inactive paths are removed", %{
      tmp_dir: tmp_dir,
      active_issues: active_issues
    } do
      MiniSymphony.Workspace.cleanup_stale(tmp_dir, active_issues)

      active_paths =
        tmp_dir
        |> File.ls!()
        |> Enum.map(&Path.join(tmp_dir, &1))
        |> Enum.filter(&File.dir?/1)

      expected_paths =
        Enum.map(active_issues, &MiniSymphony.Workspace.path_for_issue(tmp_dir, &1))

      assert Enum.sort(active_paths) == Enum.sort(expected_paths)
    end
  end
end
