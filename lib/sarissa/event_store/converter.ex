defmodule Sarissa.EventStore.Converter do
  @spec to_store(event :: Sarissa.Events.t()) :: Spear.Event.t()
  def to_store(%struct{} = event) do
    type = Module.split(struct) |> List.last()
    metadata = event.metadata

    Spear.Event.new(
      type,
      event,
      custom_metadata: Jason.encode!(metadata)
    )
  end

  @spec from_store(event :: Spear.Event.t()) :: Sarissa.Events.t()
  def from_store(%Spear.Event{} = event) do
    revision = Spear.Event.revision(event)
    metadata = event.metadata.custom_metadata |> Jason.decode!(keys: :atoms!)
    body = event.body
    mod = Module.concat([Sarissa.Events, event.type])

    event =
      mod.__struct__()
      |> Map.from_struct()
      |> Map.keys()
      |> Enum.reduce(mod.__struct__(), fn field, acc ->
        %{acc | field => Map.get(body, to_string(field))}
      end)

    %{event | metadata: metadata}
    |> Sarissa.Events.put_metadata(:revision, revision)
  end
end
