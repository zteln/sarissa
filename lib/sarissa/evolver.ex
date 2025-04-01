defmodule Sarissa.Evolver do
  @moduledoc """
  `Sarissa.Evolver` is used to reduce over events in a stream and return a state.
  """
  @callback initialize(opts :: keyword) :: term
  @callback handle_event(event :: map, state :: term) :: term
  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
      @before_compile unquote(__MODULE__)

      @spec evolve(opts :: keyword) :: term
      def evolve(opts) do
        channel = opts[:channel] || raise "no :channel defined"

        {state, channel} =
          case initialize(opts) do
            {state, channel} -> {state, channel}
            state -> {state, channel}
          end

        channel
        |> Sarissa.EventStore.Reader.read_events()
        |> Enum.reduce(state, &handle_event/2)
      end
    end
  end

  defmacro __before_compile__(_opts) do
    quote do
      @impl unquote(__MODULE__)
      def handle_event(_event, state), do: state
    end
  end
end
