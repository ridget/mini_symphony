defmodule MiniSymphony.IssueSource.YamlTest do
  use ExUnit.Case, async: true
  alias MiniSymphony.IssueSource.Yaml

  setup do
    tmp = Path.join(System.tmp_dir!(), "test_issues_#{System.unique_integer([:positive])}.yaml")

    yaml = """
    - id: "t1"
      identifier: "TEST-1"
      title: "Active issue"
      description: "Do something"
      state: "todo"
      priority: 1
    - id: "t2"
      identifier: "TEST-2"
      title: "Done issue"
      description: "Already done"
      state: "done"
      priority: 2
    """

    File.write!(tmp, yaml)
    on_exit(fn -> File.rm(tmp) end)
    %{path: tmp}
  end

  test "fetch_candidates returns only active issues", %{path: path} do
    issues = Yaml.fetch_candidates(path)
    assert length(issues) == 1
    assert hd(issues).identifier == "TEST-1"
    assert hd(issues).state == "todo"
  end

  test "fetch_candidates excludes terminal states", %{path: path} do
    issues = Yaml.fetch_candidates(path)
    refute Enum.any?(issues, &(&1.id == "t2"))
  end

  test "non-existent file returns error" do
    assert_raise YamlElixir.FileNotFoundError, fn ->
      Yaml.fetch_candidates("/no/such/file.yaml")
    end
  end
end
