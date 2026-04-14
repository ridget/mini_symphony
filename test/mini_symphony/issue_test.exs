defmodule MiniSymphony.IssueTest do
  use ExUnit.Case, async: true
  doctest MiniSymphony.Issue
  alias MiniSymphony.Issue

  test "creating an issue with required fields works" do
    {:ok, result} =
      Issue.new(%{
        "id" => "issue-1",
        "identifier" => "ISSUE-1",
        "title" => "List files and summarise",
        "state" => "todo"
      })

    assert %Issue{} = result

    assert result.priority == 99
  end

  test "missing fields return error message" do
    {:error, message} =
      Issue.new(%{
        "identifier" => "ISSUE-1",
        "title" => "List files and summarise",
        "state" => "todo"
      })

    assert(message == "missing the following fields id")
  end
end
