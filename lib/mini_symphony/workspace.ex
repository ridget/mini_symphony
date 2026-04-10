defmodule MiniSymphony.Workspace do
  def create_for_issue(workspace_root, %MiniSymphony.Issue{} = issue) do
    path =
      path_for_issue(workspace_root, issue)
      |> File.mkdir_p!()

    {:ok, path}
  end

  def remove(path) do
    File.rm_rf(path)
  end

  def cleanup_stale(workspace_root, active_issues) do
    # find all directories in the workspace root
    # delete if not in active issues path for issue

    active_paths =
      active_issues
      |> Stream.map(&path_for_issue(workspace_root, &1))
      |> MapSet.new()

    workspace_root
    |> File.ls!()
    |> Stream.map(&Path.join(workspace_root, &1))
    |> Stream.filter(&File.dir?/1)
    |> Stream.reject(&MapSet.member?(active_paths, &1))
    |> Enum.each(&File.rm_rf!/1)
  end

  defp sanitize_issue_identifier(identifier) do
    String.replace(identifier, ~r/[^A-Za-z0-9._-]/, "-")
  end

  def path_for_issue(workspace_root, issue) do
    sanitized_issue_identifier = sanitize_issue_identifier(issue.identifier)
    Path.join(workspace_root, sanitized_issue_identifier)
  end
end
