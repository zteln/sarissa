defmodule Sarissa.EventStore.SubscriptionLink do
  use GenServer
  alias Sarissa.EventStore
  alias Sarissa.EventStore.Converter

  defstruct [:pid, :channel, :ref]

  def start_link(opts) do
    pid = opts[:pid] || "no :pid specified"
    channel = opts[:channel] || "no :channel specified"
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
  def handle_info(%Spear.Event{} = spear_event, state) do
    event = Converter.from_store(spear_event)
    send(state.pid, {:event, event})
    {:noreply, state}
  end
end
