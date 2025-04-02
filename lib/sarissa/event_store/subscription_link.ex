defmodule Sarissa.EventStore.SubscriptionLink do
  use GenServer
  require Logger
  alias Sarissa.EventStore
  alias Sarissa.EventStore.Converter

  defstruct [:pid, :channel, :ref]

  def start_link(opts) do
    opts[:pid] || "no :pid specified"
    opts[:channel] || "no :channel specified"
    GenServer.start_link(__MODULE__, Keyword.take(opts, [:pid, :channel]))
  end

  @impl GenServer
  def init(opts) do
    channel = opts[:channel]

    case EventStore.subscribe(self(), channel.name, from: channel.revision) do
      {:ok, ref} ->
        {:ok,
         %__MODULE__{
           pid: opts[:pid],
           channel: opts[:channel],
           ref: ref
         }}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_info(%Spear.Event{} = event, state) do
    send(state.pid, {:event, Converter.from_store(event)})
    {:noreply, state}
  end

  def handle_info({:eos, subscription, reason}, state) do
    Logger.debug(fn ->
      "Subscription #{inspect(subscription)} ended, reason: #{inspect(reason)}"
    end)

    {:stop, :normal, state}
  end
end
