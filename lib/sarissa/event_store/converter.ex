defmodule Sarissa.EventStore.Converter do
  def to_store(%struct{} = event) do
    type = Module.split(struct) |> List.last()
    Spear.Event.new(type, Map.from_struct(event))
  end

  def from_store(%Spear.Event{} = event) do
    mod = Module.concat([event.type])
    body = event.body
    new = struct(mod, %{})

    Map.keys(new)
    |> Enum.reduce(new, fn field, acc ->
      Map.put(acc, field, Map.get(body, to_string(field)))
    end)
  end
end
