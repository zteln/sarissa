defmodule Sarissa.Evolver do
  @moduledoc """
  `Sarissa.Evolver` is used to reduce over events in a stream and return a state.
  """
  @callback initialize(opts :: keyword) :: {Sarissa.EventStore.Channel.t(), term} | term
  @callback handle_event(event :: map, state :: term) :: term
  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
      @before_compile unquote(__MODULE__)

      @spec evolve(channel :: Sarissa.EventStore.Channel.t(), opts :: keyword) ::
              {Sarissa.EventStore.Channel.t(), term}
      # @spec evolve(opts :: keyword) :: term
      def evolve(channel, opts \\ []) do
        {channel, state} =
          case initialize(opts) do
            {channel, state} -> {channel, state}
            state -> {channel, state}
          end

        channel
        |> Sarissa.EventStore.Reader.read_events()
        # |> Enum.reduce(state, &handle_event/2)
        |> Enum.reduce({channel, state}, fn event, {channel, state} ->
          revision = get_in(event, [Access.key(:metadata), Access.key(:revision)])

          {Sarissa.EventStore.Channel.update_revision(channel, revision),
           handle_event(event, state)}
        end)
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
