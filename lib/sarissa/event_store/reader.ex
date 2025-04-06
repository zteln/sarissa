defmodule Sarissa.EventStore.Reader do
  alias Sarissa.EventStore
  alias Sarissa.EventStore.Channel
  alias Sarissa.EventStore.Converter

  @spec read_events(channel :: Channel.t()) :: {:ok, Channel.t(), Enumerable.t()} | {:error, term}
  def read_events(%Channel{revision: :any} = channel) do
    channel
    |> Channel.update_revision(:start)
    |> read_events()
  end

  def read_events(%Channel{} = channel) do
    revision =
      if channel.revision == :start do
        :start
      else
        channel.revision + 1
      end

    filter = if channel.name == :all, do: channel.filter

    opts = [from: revision, filter: filter]

    case EventStore.read_stream(channel.name, opts) do
      {:ok, events} ->
        channel =
          events
          |> Stream.take(-1)
          |> Enum.to_list()
          |> case do
            [] -> channel
            [last_event] -> Channel.update_revision(channel, Spear.Event.revision(last_event))
          end

        {:ok, channel, Stream.map(events, &Converter.from_store/1)}

      {:error, _reason} = error ->
        error
    end
  end

  def read_events(_channel), do: {:error, :no_valid_channel}

  @spec subscribe(channel :: Channel.t()) :: {:ok, reference} | {:error, term}
  def subscribe(channel) do
    EventStore.subscribe(self(), channel.name, from: channel.revision)
  end
end
