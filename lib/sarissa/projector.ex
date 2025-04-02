defmodule Sarissa.Projector do
  @moduledoc """
  `Sarissa.Projector` is a `GenServer` wrapper around `Sarissa.Evolver` such that state is long-lived.
  The callbacks from `Sarissa.Evolver` must be defined in the implementation.
  """
  def call(projector, call, timeout \\ 5000) do
    call!(projector, call, timeout)
  catch
    {:exit, {:timeout, _}} -> {:error, :timeout}
  end

  def call!(projector, call, timeout \\ 5000), do: GenServer.call(projector, call, timeout)

  def state(projector, timeout \\ 5000), do: call(projector, :get_projection_state, timeout)

  def catch_up(projector), do: call(projector, :catch_up)
  def start_subscription(projector), do: call(projector, :start_subscription)
  def cancel_subscription(projector), do: call(projector, :cancel_subscription)

  defmacro __using__(_opts) do
    quote do
      use Sarissa.Evolver
      use GenServer

      defstruct [:channel, :projection]

      def start_link(opts) do
        GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
      end

      @impl GenServer
      def init(opts) do
        channel = opts[:channel] || raise "no :channel defined"

        {:ok, %__MODULE__{channel: channel}, {:continue, :evolve}}
      end

      @impl GenServer
      def handle_continue(:evolve, state) do
        state =
          state
          |> catch_up()
          |> subscribe()

        {:noreply, state}
      end

      @impl GenServer
      def handle_call(:get_projection_state, _from, state) do
        {:reply, state.projection, state}
      end

      def handle_call(:catch_up, _from, state) do
        state = catch_up(state)
        {:reply, :ok, state}
      end

      def handle_call(:start_subscription, _from, state) do
        subscribe(state)
        {:reply, :ok, state}
      end

      def handle_call(:cancel_subscription, _from, state) do
        Sarissa.EventStore.SubscriptionRouter.cancel_subscription(self())
        {:reply, :ok, state}
      end

      @impl GenServer
      def handle_info({:event, event}, state) do
        projection = handle_event(event, state.projection)
        {:noreply, %{state | projection: projection}}
      end

      defp catch_up(state) do
        {channel, state} = evolve(channel: state.channel)
        %{state | projection: projection, channel: channel}
      end

      defp subscribe(state) do
        Sarissa.EventStore.SubscriptionRouter.start_subscription(self(), state.channel)
        state
      end
    end
  end
end
