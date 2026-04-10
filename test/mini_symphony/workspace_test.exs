defmodule MiniSymphony.WorkspaceTest do
  use ExUnit.Case, async: true
  doctest MiniSymphony.Workspace

  @moduletag :tmp_dir

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

  describe "create_for_issue/2" do
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
      {:ok, [deleted_path]} = MiniSymphony.Workspace.remove(path_to_delete)

      assert(deleted_path == path_to_delete)

      refute File.exists?(path_to_delete)
    end
  end
end
