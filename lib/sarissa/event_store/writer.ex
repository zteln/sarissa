defmodule Sarissa.EventStore.Writer do
  alias Sarissa.EventStore
  alias Sarissa.EventStore.Channel
  alias Sarissa.EventStore.Converter

  @spec write_events(channel :: Channel.t(), events :: Enumerable.t()) ::
          {:ok, Channel.t()} | {:error, term}
  def write_events(%Channel{} = channel, []), do: {:ok, channel}

  def write_events(%Channel{} = channel, events) do
    revision = if channel.revision == :start, do: :empty, else: channel.revision

    events
    |> Enum.map(&Converter.to_store/1)
    |> EventStore.append(channel.name, expect: revision)
    |> case do
      :ok ->
        channel = Channel.update_revision_with(channel, length(events))
        {:ok, channel}

      {:error, _reason} = error ->
        error
    end
  end
end
