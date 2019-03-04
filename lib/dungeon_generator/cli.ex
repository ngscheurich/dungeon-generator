defmodule DungeonGenerator.CLI do
  @moduledoc """
  Functions for the command-line interface.
  """

  alias DungeonGenerator.GrowingTree

  def main(argv \\ []) do
    argv
    |> parse_argv
    |> run
  end

  defp parse_argv(argv) do
    {_, args, _} = OptionParser.parse(argv, switches: [])
    args
  end

  defp run([width, height]) do
    width = String.to_integer(width)
    height = String.to_integer(height)
    GrowingTree.run(width, height)
  end

  defp run(_args) do
    GrowingTree.run()
  end
end
