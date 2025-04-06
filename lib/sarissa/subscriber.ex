defmodule Sarissa.Subscriber do
  use GenServer
  require Logger
  alias Sarissa.EventStore.Reader
  alias Sarissa.EventStore.Converter

  defstruct [:connector, :subscription_ref]

  def start_link(opts) do
    opts[:connector] || raise "no connector found"
    opts[:channel] || raise "no channel found"
    GenServer.start_link(__MODULE__, Keyword.take(opts, [:connector, :channel]))
  end

  @impl GenServer
  def init(opts) do
    Logger.debug(fn -> "Subscriber starting for connector #{inspect(opts[:connector])}" end)
    {:ok, subscription_ref} = Reader.subscribe(opts[:channel])
    {:ok, %__MODULE__{connector: opts[:connector], subscription_ref: subscription_ref}}
  end

  @impl GenServer
  def handle_info(%Spear.Event{} = event, state) do
    event = Converter.from_store(event)
    send(state.connector, {:event, event})
    {:noreply, state}
  end

  def handle_info(%Spear.Filter.Checkpoint{} = checkpoint, state) do
    send(state.connector, {:checkpoint, checkpoint})
    {:noreply, state}
  end

  def handle_info({:caught_up, subscription_ref}, state) do
    Logger.debug(fn -> "Caught up with subscription reference: #{inspect(subscription_ref)}" end)
    {:noreply, state}
  end

  def handle_info({:eos, _subscription_ref, reason}, state) do
    Logger.warning(fn -> "Subscription terminated, reason: #{inspect(reason)}" end)
    {:stop, :normal, state}
  end

  def handle_info({:EXIT, connector, :unsubscribe}, state) do
    Logger.debug(fn -> "Received :unsubscribe from #{inspect(connector)}" end)
    {:stop, :unsubscribe, state}
  end

  def handle_info({:EXIT, _connector, exit_reason}, state) do
    Logger.warning(fn -> "Connector terminated with reason: #{inspect(exit_reason)}" end)
    {:stop, :normal, state}
  end
end
