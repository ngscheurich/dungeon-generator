defmodule DungeonGenerator.CLI do
  @moduledoc """
  Functions for the command-line interface.
  """

  alias DungeonGenerator.GrowingTree

  def main(_args) do
    GrowingTree.run()
  end
end
