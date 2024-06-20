defmodule Tab2lilypond do
  @number2note %{
    0 => "c",
    1 => "cis",
    2 => "d",
    3 => "dis",
    4 => "e",
    5 => "f",
    6 => "fis",
    7 => "g",
    8 => "gis",
    9 => "a",
    10 => "ais",
    11 => "b"
  }

  @strings %{
    "e" => 28,
    "B" => 23,
    "G" => 19,
    "D" => 14,
    "A" => 9,
    "E" => 4
  }

  def parse(tab) do
    tab
    |> String.split()
    |> Enum.chunk_every(6)
    |> Enum.map(fn n -> Tab2lilypond.parse_all(n) end)
    |> Enum.join("\n")
  end

  def parse_all(tab) do
    spaces = find_spaces(tab)

    tab =
      tab
      |> Enum.map(fn n -> String.replace(n, "-|", "") end)
      |> Enum.map(fn line -> parse_line(line) end)
      |> List.flatten()
      |> Enum.sort_by(fn {_, height, pos} -> pos || height end)

    silences =
      tab
      |> Enum.group_by(fn {_, _, pos} -> pos end)
      |> Map.to_list()
      |> Enum.map(fn {_pos, info} -> info end)
      |> Enum.map(fn tuple -> Enum.map(tuple, fn n -> Tuple.to_list(n) end) end)

    silences = list_silences(silences)

    tab =
      tab
      |> Enum.filter(fn n -> Enum.at(Tuple.to_list(n), 0) != "-" end)

    tab =
      tab
      |> Enum.map(fn {val, height, pos} -> accentuation(tab, {val, height, pos}) end)

    tab = tab ++ silences

    tab =
      tab
      |> Enum.sort_by(fn {_, height, pos} -> pos || height end)

    quotes = first_quote(Enum.at(tab, 0))

    tab =
      tab
      |> Enum.group_by(fn {_, _, pos} -> pos end)
      |> Map.to_list()
      |> Enum.map(fn {_pos, info} -> info end)
      |> Enum.map(fn tuple -> Enum.map(tuple, fn n -> Tuple.to_list(n) end) end)
      |> Enum.map(fn list -> Enum.map(list, fn n -> Enum.at(n, 0) end) end)
      |> Enum.map(fn notes -> same_time(notes) end)

    tab
    |> Enum.with_index()
    |> Enum.map(fn n -> Tuple.to_list(n) end)
    |> Enum.map(fn [val, index] -> insert_spaces(tab, val, index, spaces) end)
    |> (fn l -> [hd(l) <> quotes | tl(l)] end).()
    |> Enum.join(" ")
    |> (fn s -> "\\relative { #{s} }" end).()
  end

  def first_quote({_val, height, _pos}) do
    quotes = String.duplicate("'", Integer.floor_div(height, 12))
    quotes <> "8"
  end

  def find_spaces(tab) do
    pos =
      tab
      |> Enum.at(0)
      |> String.graphemes()
      |> Enum.with_index()
      |> Enum.filter(fn {element, _index} -> element == "|" end)
      |> Enum.map(fn n -> Tuple.to_list(n) end)
      |> Enum.map(fn [_s, index] -> index end)
      |> Enum.at(1)

    Integer.floor_div(pos - 3, 2)
  end

  def insert_spaces(tab, val, index, spaces) do
    index = index + 1

    if rem(index, spaces) == 0 && index != length(tab) do
      val <> " |"
    else
      val
    end
  end

  def accentuation(tab, {val, height, pos}) do
    index = Enum.find_index(tab, fn n -> n == {val, height, pos} end)

    if index < length(tab) && index > 0 do
      up_down = Enum.at(Tuple.to_list(Enum.at(tab, index - 1)), 1) - height

      if up_down > 5 do
        {val <> ",", height, pos}
      else
        if up_down < -5 do
          {val <> "'", height, pos}
        else
          {val, height, pos}
        end
      end
    else
      {val, height, pos}
    end
  end

  def same_time(notes) do
    if length(notes) > 1 do
      "<< #{Enum.join(notes, " ")} >>"
    else
      Enum.join(notes)
    end
  end

  def parse_line(line) do
    note = Map.get(@strings, String.at(line, 0))

    line =
      line
      |> String.graphemes()
      |> Enum.with_index()
      |> List.delete_at(0)
      |> List.delete_at(0)

    if Enum.filter(line, fn {str, _pos} -> str =~ ~r/\d+/ end) == [] do
      []
    else
      line = Enum.filter(line, fn n -> rem(Enum.find_index(line, fn x -> x == n end), 2) == 1 end)
      Enum.map(line, fn {str, pos} -> silence_line(str, pos, note) end)
    end
  end

  def silence_line(str, pos, note) do
    if str == "-" do
      {str, 0, pos}
    else
      {Map.get(@number2note, rem(String.to_integer(str) + note, 12)),
       String.to_integer(str) + note, pos}
    end
  end

  def list_silences(tab) do
    tab
    |> Enum.map(fn n -> Enum.filter(n, fn x -> Enum.at(x, 0) != "-" end) end)
    |> Enum.with_index()
    |> Enum.filter(fn {element, _index} -> element == [] end)
    |> Enum.map(fn {_element, index} -> index end)
    |> Enum.map(fn n -> Enum.at(tab, n) end)
    |> Enum.map(fn n -> Enum.uniq(n) end)
    |> Enum.map(fn n -> Enum.at(n, 0) end)
    |> Enum.map(fn n -> List.replace_at(n, 0, "r") end)
    |> Enum.map(fn n -> List.to_tuple(n) end)
  end
end
