defmodule Sarissa.EventStore.SubscriptionRouter do
  # TODO refactor into separate functions
  use GenServer
  alias Sarissa.EventStore

  defstruct callers: %{}, links: %{}

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def start_subscription(pid, channel) do
    GenServer.call(__MODULE__, {:start_subscription, pid, channel})
  end

  def cancel_subscription(pid, channel) do
    GenServer.call(__MODULE__, {:cancel_subscription, pid})
  end

  @impl GenServer
  def init(_) do
    {:ok, %__MODULE__{}}
  end

  @impl GenServer
  def handle_call({:start_subscription, pid, channel}, _from, state) do
    link_pid = SubscriptionLink.start_link(pid: pid, channel: channel)
    Process.monitor(pid)
    Process.monitor(link_pid)

    state = %{
      state
      | callers: Map.put(state.callers, pid, link_pid),
        links: Map.put(state.links, link_pid, pid)
    }

    {:reply, :ok, state}
  end

  def handle_call({:cancel_subscription, pid}, _from, state) do
    link_pid = Map.get(state.callers, pid)
    :ok = GenServer.stop(link_pid)

    state = %{
      state
      | callers: Map.delete(state.callers, pid),
        links: Map.delete(state.links, link_pid)
    }

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info({:DOWN, _monitor_ref, :process, pid, _exit_reason}, state) do
    state =
      if Map.has_key?(state.callers, pid) do
        link_pid = Map.get(state.callers, pid)
        :ok = GenServer.stop(link_pid)

        %{
          state
          | callers: Map.delete(state.callers, pid),
            links: Map.delete(state.links, link_pid)
        }
      else
        caller_pid = Map.get(state.links, pid)
        Sarissa.Projector.start_subscription(caller_pid)

        %{
          state
          | callers: Map.delete(state.callers, caller_pid),
            links: Map.delete(state.links, pid)
        }
      end

    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}
end
