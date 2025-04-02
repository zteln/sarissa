defmodule Sarissa.EventStore.Reader do
  alias Sarissa.EventStore
  alias Sarissa.EventStore.Channel
  alias Sarissa.EventStore.Converter
  alias Sarissa.EventStore.SubscriptionRouter

  @spec read_events(channel :: Channel.t()) :: Enumerable.t() | {:error, term}
  def read_events(%Channel{} = channel) do
    EventStore.stream!(channel.name, from: channel.revision)
    |> Stream.map(&Converter.from_store/1)
  end

  def read_events(_channel), do: {:error, :no_valid_channel}

  @spec subscribe(channel :: Channel.t()) :: {:ok, reference} | {:error, term}
  def subscribe(channel) do
    SubscriptionRouter.start_subscription(self(), channel, from: channel.revision)
  end
end
