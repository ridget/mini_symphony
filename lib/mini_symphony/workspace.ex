defmodule MiniSymphony.Workspace do
  def create_for_issue(workspace_root, %MiniSymphony.Issue{} = issue) do
    sanitized_issue_identifier = sanitize_issue_identifier(issue.identifier)
    path = Path.join(workspace_root, sanitized_issue_identifier)

    File.mkdir_p!(path)

    {:ok, path}
  end

  def remove(path) do
    File.rm_rf(path)
  end

  defp sanitize_issue_identifier(identifier) do
    String.replace(identifier, ~r/[^A-Za-z0-9._-]/, "-")
  end
end
