defmodule Sarissa.EventStore.Converter do
  @spec to_store(event :: Sarissa.Events.t()) :: Spear.Event.t()
  def to_store(%struct{} = event) do
    type = Module.split(struct) |> List.last()

    Spear.Event.new(
      type,
      event
    )
  end

  @spec from_store(event :: Spear.Event.t()) :: Sarissa.Events.t()
  def from_store(%Spear.Event{} = event) do
    revision = Spear.Event.revision(event)

    mod = Module.concat([Sarissa.Events, event.type])
    body = event.body

    event =
      mod.__struct__()
      |> Map.from_struct()
      |> Map.keys()
      |> Enum.reduce(mod.__struct__(), fn field, acc ->
        %{acc | field => Map.get(body, to_string(field))}
      end)

    %{event | metadata: Sarissa.Events.Metadata.new(revision: revision)}
  end
end
