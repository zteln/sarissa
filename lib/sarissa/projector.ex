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
        projection = evolve(channel: state.channel)
        Sarissa.EventStore.Reader.subscribe(state.channel)
        {:noreply, %{state | projection: projection}}
      end

      @impl GenServer
      def handle_call(:get_projection_state, _from, state) do
        {:reply, state.projection, state}
      end

      @impl GenServer
      def handle_info({:event, event}, state) do
        projection = handle_event(event, state.projection)
        {:noreply, %{state | projection: projection}}
      end
    end
  end
end
