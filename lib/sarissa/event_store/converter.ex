defmodule Sarissa.EventStore.Converter do
  def to_store(%struct{} = event) do
    type = Module.split(struct) |> List.last()
    Spear.Event.new(type, Map.from_struct(event))
  end

  def from_store(%Spear.Event{} = event) do
    mod = Module.concat([Sarissa.Events, event.type])
    body = event.body

    mod.__struct__()
    |> Map.from_struct()
    |> Map.keys()
    |> Enum.reduce(mod.__struct__(), fn field, acc ->
      %{acc | field => Map.get(body, to_string(field))}
    end)
  end
end
