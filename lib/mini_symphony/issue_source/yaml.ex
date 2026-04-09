defmodule MiniSymphony.IssueSource.Yaml do
  alias MiniSymphony.Issue

  def fetch_candidates(file_path) do
    fetch_all(file_path)
  end

  def fetch_by_ids(file_path, ids) do
    fetch_all(file_path)
    |> Enum.filter(fn issue -> issue.id in ids end)
  end

  defp fetch_all(file_path) do
    file_path
    |> YamlElixir.read_from_file!()
    |> Enum.map(&Issue.new/1)
    |> Enum.flat_map(fn
      {:ok, issue} -> [issue]
      # Silently skip malformed YAML entries
      {:error, _reason} -> []
    end)
    |> Enum.filter(fn issue -> issue.state in Issue.active_states() end)
  end
end
