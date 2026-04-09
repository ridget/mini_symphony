defmodule MiniSymphony.IssueSource.Yaml do
  alias MiniSymphony.Issue

  def fetch_candidates(file_path) do
    fetch_all(file_path)
  end

  def fetch_by_ids(file_path, ids) do
    fetch_all(file_path)
    |> Enum.filter(fn issue -> issue.id in ids end)
  end

  def update_state(file_path, id, new_state) do
    yaml_doc =
      fetch_all(file_path)
      |> Enum.map(fn
        %Issue{id: ^id} = issue -> %{issue | state: new_state}
        issue -> issue
      end)
      |> Ymlr.document!()

    File.write!(file_path, yaml_doc)
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
