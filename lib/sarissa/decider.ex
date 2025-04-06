defmodule Sarissa.Decider do
  @moduledoc """
  `Sarissa.Decider` is used for post-processing events.
  This module is used to define either a command or a query, since both are treated the same.

  The callback `state/1` returns the state for which to decide actions upon.
  The callback `decide/2` returns the decision made and can be one of three things:
  - `{:write, events}`: a command was processed and events are written to the event store.
  - `{:read, result}`: a query was processed and results are returned to the caller.
  - `{:error, reason}`: something went wrong processing the decision.

  ## Examples
  A simple command that pushes events into a list as state.
  The decision is made on the length of the state.
  The state is received by using `Sarissa.Evolver`.
    ```elixir
    defmodule Command do
      use Sarissa.Decider, [:id]
      use Sarissa.Evolver

      @impl Sarissa.Evolver
      def initialize(_opts), do: []

      @impl Sarissa.Evolver
      def handle_event(%Event{} = event, state), do: [event | state]

      @impl Sarissa.Decider
      def state(opts), do: evolve(opts)

      @impl Sarissa.Decider
      def decide(%__MODULE__{} = _command, state) do
        if length(state) < 5 do
          {:write, [%Event{}]}
        else
          {:error, :invalid_command}
        end
      end
    end
    Sarissa.Decider.execute(%Command{}, [channel: channel])
    ```

  A simple query that uses `Sarissa.Projector` to keep state alive.
    ```elixir
    defmodule Query do
      use Sarissa.Decider, [:id]
      use Sarissa.Projector

      @impl Sarissa.Evolver
      def initialize(_opts), do: []

      @impl Sarissa.Evolver
      def handle_event(%Event{} = event, state), do: [event | state]

      @impl Sarissa.Decider
      def state(opts), do: Sarissa.Projector.state(opts[:projector])

      @impl Sarissa.Decider
      def decide(%__MODULE__{} = _query, state) do
        {:read, Enum.map(state, &Map.get(&1, :name))}
      end
    end
    Sarissa.Decider.execute(%Query{}, [projector: projector])
    ```
  """

  alias Sarissa.EventStore.Writer
  alias Sarissa.EventStore.Channel

  @callback context(id :: term, opts :: keyword) :: Sarissa.Context.new()
  @callback decide(command_or_query :: struct, state :: term) ::
              {:write, events :: Enumerable.t(), channel :: Channel.t()}
              | {:read, result :: term}
              | {:error, term}
  defmacro __using__(fields) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)

      @enforce_keys [:id]
      defstruct unquote(fields)

      @impl unquote(__MODULE__)
      def context(_id, opts), do: Sarissa.Context.new()
      defoverridable context: 2
    end
  end

  @spec execute(command_or_query :: struct, opts :: keyword) ::
          {:ok, Channel.t() | term} | {:error, term}
  def execute(%mod{} = command_or_query, opts \\ []) do
    context = mod.context(command_or_query.id, opts)

    case mod.decide(command_or_query, context.state) do
      {:write, events} ->
        (context.channel && Writer.write_events(context.channel, events)) ||
          raise "no channel to write events to"

      {:read, result} ->
        {:ok, result}

      {:error, _reason} = error ->
        error
    end
  end
end
