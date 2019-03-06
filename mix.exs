defmodule Dungeon.Mixfile do
  use Mix.Project

  def project do
    [
      app: :dungeon_generator,
      version: "0.0.1",
      elixir: "~> 1.2",
      escript: escript(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [mod: {DungeonGenerator.Application, []}]
    [applications: [:logger]]
  end

  defp escript do
    [
      main_module: DungeonGenerator.CLI,
      path: "bin/dungeon_generator"
    ]
  end

  defp deps do
    [
      {:bunt, "~> 0.2.0"},
      {:credo, "~> 1.0.0", only: [:dev, :test], runtime: false}
    ]
  end
end
