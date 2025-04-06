defmodule Sarissa.Evolver do
  @moduledoc """
  `Sarissa.Evolver` is used to reduce over events in a stream and return a state.
  """
  @callback initial_context(opts :: keyword) :: Sarissa.Context.t()
  @callback handle_event(event :: map, state :: term) :: term
  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
      @before_compile unquote(__MODULE__)

      @impl unquote(__MODULE__)
      def initial_context(_opts), do: %Sarissa.Context{}
      defoverridable initial_context: 1

      @spec evolve(channel :: Sarissa.EventStore.Channel.t(), opts :: keyword) ::
              {Sarissa.EventStore.Channel.t(), term}
      def evolve(events, state) do
        Enum.reduce(events, state, &handle_event/2)
      end

      if Sarissa.Decider in Module.get_attribute(__MODULE__, :behaviour) do
        @impl Sarissa.Decider
        def context(id, opts) do
          # TODO alternative to passing id?
          opts = Keyword.put(opts, :id, id)
          context = initial_context(opts)

          channel =
            opts[:channel] ||
              context.channel ||
              raise "no channel provided"

          initial_state = context.state

          {:ok, channel, events} = Sarissa.EventStore.Reader.read_events(channel)
          state = evolve(events, initial_state)
          Sarissa.Context.new(channel: channel, state: state)
        end

        defoverridable context: 2
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
