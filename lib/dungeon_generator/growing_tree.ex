defmodule DungeonGenerator.GrowingTree do
  @moduledoc """
  Implements the growing tree algorithm to generate a series of rooms
  interconnected by corridors.
  """

  require Bitwise

  @type grid :: [[integer]]
  @type room :: {integer, integer, integer, integer}
  @type card :: :n | :s | :e | :w
  @type direction ::
          {:n, {1, 0, -1}}
          | {:s, {2, 0, 1}}
          | {:e, {4, 1, 0}}
          | {:w, {8, -1, 0}}
  @type directions ::
          %{required(card) => {integer, integer, integer}} | [direction]

  @type cell :: {integer, integer}

  @directions %{
    n: {1, 0, -1},
    s: {2, 0, 1},
    e: {4, 1, 0},
    w: {8, -1, 0}
  }

  @doc """
  Runs the algorithm, generating a dungeon of `width`×`height` dimensions.
  """
  @spec run(integer, integer) :: :ok
  def run(width \\ 50, height \\ 50) do
    grid =
      0..(height - 1)
      |> Enum.map(fn _y ->
        0..(width - 1)
        |> Enum.map(fn _x ->
          0
        end)
      end)

    # TODO: Move to drawing module
    IO.write("\e[2J")

    {grid, rooms} = create_rooms(width, height, grid, 1000)

    grid = carve_passages(width, height, grid)

    grid = find_connectors(grid, rooms)

    grid = remove_deadends(grid)

    print(grid)
  end

  @doc """
  Generates a set of randomly located, non-overlapping rooms.

  If a room collides with a previously placed one, it is discarded. This
  ensures there are no overlaps.

  In order to avoid an infinite loop and to allow for some tuning of room
  density, a fixed number of `attempts` are performed.
  """
  @spec create_room(integer, integer, grid) :: {grid, [room]}
  def create_rooms(grid_width, grid_height, grid, attempts \\ 200) do
    rooms =
      Enum.reduce(1..attempts, [], fn _n, rooms ->
        room = create_room(grid_width, grid_height)

        unless overlaps?(rooms, room) do
          [room | rooms]
        else
          rooms
        end
      end)

    grid =
      rooms
      |> Enum.reduce(grid, fn {x, y, width, height}, grid ->
        y..(y + height)
        |> Enum.reduce(grid, fn uy, grid ->
          x..(x + width)
          |> Enum.reduce(grid, fn ux, grid ->
            update_cell(grid, ux, uy, 16)
          end)
        end)
      end)

    {grid, rooms}
  end

  @spec create_room(integer, integer, Range.t()) :: room
  defp create_room(grid_width, grid_height, size_range \\ 2..3) do
    size = Enum.random(size_range)
    {room_width, room_height} = {size, size}

    room_y_index = Enum.random(1..(grid_height - room_height - 2))
    room_x_index = Enum.random(1..(grid_width - room_width - 2))

    {room_x_index, room_y_index, room_width, room_height}
  end

  @spec overlaps?([room], room) :: boolean
  defp overlaps?(rooms, {x, y, width, height}) do
    Enum.any?(rooms, fn {other_x, other_y, other_width, other_height} ->
      not (x + width + 2 < other_x or
             other_x + other_width + 2 < x or
             y + height + 2 < other_y or
             other_y + other_height + 2 < y)
    end)
  end

  @spec update_cell(grid, integer, integer, integer) :: grid
  defp update_cell(grid, x, y, 0) do
    row = Enum.at(grid, y)
    row = List.replace_at(row, x, 0)
    List.replace_at(grid, y, row)
  end

  defp update_cell(grid, x, y, bw) do
    row = Enum.at(grid, y)
    cell = Enum.at(row, x)
    cell = Bitwise.bor(cell, bw)
    row = List.replace_at(row, x, cell)
    List.replace_at(grid, y, row)
  end

  @spec carve_passages(integer, integer, grid) :: grid
  defp carve_passages(width, height, grid) do
    x = Enum.random(0..(width - 1))
    y = Enum.random(0..(height - 1))
    cells = [{x, y}]
    carve_cells(grid, cells)
  end

  @spec carve_cells(grid, [cell]) :: grid
  defp carve_cells(grid, cells) when length(cells) > 0 do
    directions = Enum.shuffle(@directions)
    carve_cells(grid, cells, directions)
  end

  defp carve_cells(grid, _cells), do: grid

  @spec carve_cells(grid, [cell], list) :: grid
  defp carve_cells(grid, cells, directions) when is_list(directions) do
    cell = List.first(cells)
    carve_cells(grid, cells, cell, directions)
  end

  @spec carve_cells(grid, [cell], {card, any}) :: grid
  defp carve_cells(grid, cells, {card, _}) do
    {direction, directions} = Map.pop(@directions, card)
    cell = List.first(cells)
    carve_cells(grid, cells, cell, directions, {card, direction})
  end

  @spec carve_cells(grid, [cell], cell, [direction]) :: grid
  defp carve_cells(grid, cells, cell, directions) when length(directions) > 0 do
    key = directions |> Keyword.keys() |> List.first()
    {direction, directions} = Keyword.pop(directions, key)
    carve_cells(grid, cells, cell, directions, {key, direction})
  end

  defp carve_cells(grid, cells, _cell, _directions) do
    [_removed | updated_cells] = cells
    carve_cells(grid, updated_cells)
  end

  @spec carve_cells(grid, [cell], cell, directions, direction) :: grid
  defp carve_cells(
         grid,
         cells,
         {x, y} = cell,
         directions,
         {_, {bw, dx, dy}} = direction
       )
       when length(cells) > 0 do
    nx = x + dx
    ny = y + dy
    row = Enum.at(grid, ny)

    if row do
      grid_cell = Enum.at(row, nx)

      if ny in 0..(length(grid) - 1) and nx in 0..(length(row) - 1) and
           grid_cell == 0 do
        grid =
          grid
          |> update_cell(x, y, bw)
          |> update_cell(nx, ny, opposite(direction))

        print(grid)
        # :timer.sleep(10)
        cells = [{nx, ny} | cells]

        # we want to "weight" it in favour of going in straighter lines, so reuse the same direction
        carve_cells(grid, cells, direction)
        # carve_cells(grid, cells)
      else
        carve_cells(grid, cells, cell, directions)
      end
    else
      carve_cells(grid, cells, cell, directions)
    end
  end

  @spec find_connectors(grid, [room]) :: grid
  defp find_connectors(grid, rooms) do
    Enum.map(rooms, fn {x, y, width, height} = room ->
      y = Enum.random(y..(y + height))
      x = Enum.random([x, x + width])
      {room, x, y}
    end)
    |> Enum.reduce(grid, fn {{rx, _, _, _}, x, y}, grid ->
      grid = update_cell(grid, x, y, 32)

      {_card, {bw, dx, dy}} =
        direction =
        if x == rx do
          # on the eastern side of the room
          # open to the west
          get_direction(:w)
        else
          # on the western side of the woom
          # open to the east
          get_direction(:e)
        end

      grid = update_cell(grid, x, y, bw)
      nx = x + dx
      ny = y + dy
      update_cell(grid, nx, ny, opposite(direction))
    end)
  end

  @spec get_direction(card()) :: direction()
  defp get_direction(card) do
    {card, Map.fetch!(@directions, card)}
  end

  @spec opposite({card(), any()}) :: integer()
  defp opposite({card, _}), do: opposite(card)

  @spec opposite(card()) :: integer()
  defp opposite(card) do
    {_, {bw, _, _}} =
      case card do
        :n -> :s
        :s -> :n
        :w -> :e
        :e -> :w
      end
      |> get_direction()

    bw
  end

  defp get_exits(cell) do
    Enum.reduce(@directions, [], fn {_card, {bw, _dx, _dy}} = direction,
                                    exits ->
      if Bitwise.band(cell, bw) != 0 do
        [direction | exits]
      else
        exits
      end
    end)
  end

  @spec remove_deadends(grid) :: grid
  defp remove_deadends(grid) do
    grid
    |> Enum.with_index()
    |> Enum.reduce([], fn {row, y}, deadends ->
      row
      |> Enum.with_index()
      |> Enum.reduce(deadends, fn {cell, x}, deadends ->
        # not a door
        if Bitwise.band(cell, 32) == 0 do
          exits = get_exits(cell)

          if length(exits) == 1 do
            [{x, y, List.first(exits)} | deadends]
          else
            deadends
          end
        else
          deadends
        end
      end)
    end)
    |> remove_deadends(grid)
  end

  @spec remove_deadends(list, grid) :: grid
  defp remove_deadends([], grid), do: grid

  defp remove_deadends([deadend | deadends], grid) do
    remove_deadends(deadend, deadends, grid)
  end

  @spec remove_deadends({integer, integer, direction}, list, grid) :: grid
  defp remove_deadends({x, y, {card, {_, dx, dy}}}, deadends, grid) do
    # IO.puts "removing deadend at #{x}/#{y} with exit #{card}"
    grid = update_cell_with(grid, x, y, 0)
    nx = x + dx
    ny = y + dy
    ncell = get_cell_at(grid, nx, ny)
    bw = opposite(card)
    # exits = get_cell_at(grid, nx, ny) |> get_exits
    # IO.puts "updating exit cell at #{nx}/#{ny} xor with #{bw} with #{length(exits)} exits"
    grid = update_cell_with(grid, nx, ny, Bitwise.bxor(ncell, bw))
    exits = get_cell_at(grid, nx, ny) |> get_exits
    # IO.puts "cell should now have one less exit: #{length(exits)}"
    if length(exits) == 1 do
      # IO.puts "added to deadends"
      [{nx, ny, List.first(exits)} | deadends]
    end

    # print grid
    # :timer.sleep(10)
    remove_deadends(deadends, grid)
  end

  @spec update_cell(grid, integer, integer, integer) :: grid
  defp update_cell_with(grid, x, y, val) do
    row = Enum.at(grid, y)
    row = List.replace_at(row, x, val)
    List.replace_at(grid, y, row)
  end

  @spec get_cell_at(grid, integer, integer) :: integer
  defp get_cell_at(grid, x, y) do
    row = Enum.at(grid, y)
    Enum.at(row, x)
  end

  @spec print(grid) :: :ok
  defp print(grid) do
    # move to upper-left
    IO.write("\e[H")
    IO.write(" ")

    1..(length(Enum.at(grid, 0)) * 2 - 1)
    |> Enum.each(fn _n ->
      IO.write("_")
    end)

    IO.puts(" ")

    Enum.each(grid, fn row ->
      IO.write("|")

      row
      |> Enum.with_index()
      |> Enum.each(fn {cell, x} ->
        if Bitwise.band(cell, 16) != 0 do
          # this is a room
          next_cell = Enum.at(row, x + 1)
          # cell to the right/west is a room cell
          if Bitwise.band(next_cell, 16) != 0 do
            # door
            # cell to the right/west is *not* a room cell
            if Bitwise.band(cell, 32) != 0 do
              [:color236_background, :color150, "d"]
              |> Bunt.ANSI.format()
              |> IO.write()

              [:color236_background, :color240, "."]
              |> Bunt.ANSI.format()
              |> IO.write()
            else
              [:color236_background, :color240, ".."]
              |> Bunt.ANSI.format()
              |> IO.write()
            end
          else
            if Bitwise.band(cell, 32) != 0 do
              [:color236_background, :color150, "d "]
              |> Bunt.ANSI.format()
              |> IO.write()
            else
              [:color236_background, :color240, "."]
              |> Bunt.ANSI.format()
              |> IO.write()

              [:color236_background, "|"]
              |> Bunt.ANSI.format()
              |> IO.write()
            end
          end
        else
          # not a room
          if cell != 0 do
            # not empty (probably a corridor)
            if Bitwise.band(cell, 2) != 0 do
              # open to the south
              " "
            else
              # not open to the south
              "_"
            end
            |> write(236)

            if Bitwise.band(cell, 4) != 0 do
              # open to the east
              next_cell = Enum.at(row, x + 1)
              # is the next cell open to the south?
              if Bitwise.bor(next_cell, 2) != 0 do
                " "
              else
                "_"
              end
            else
              # not open to the east
              "|"
            end
            |> write(236)
          else
            "_|" |> write(240)
          end
        end
      end)

      IO.puts("")
    end)
  end

  @spec write(String.t(), integer) :: :ok
  defp write(text, color) do
    [String.to_atom("color#{color}_background"), text]
    |> Bunt.ANSI.format()
    |> IO.write()
  end
end
