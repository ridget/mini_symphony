defmodule MiniSymphony.MixProject do
  use Mix.Project

  def project do
    [
      app: :mini_symphony,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {MiniSymphony.Application, []}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:yaml_elixir, "~> 2.12"},
      {:ymlr, "~> 5.0"},
      {:jason, "~> 1.4"}
    ]
  end
end
