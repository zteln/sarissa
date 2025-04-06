defmodule Sarissa.EvolverTest do
  use ExUnit.Case, async: true
  import SarissaCase

  alias Sarissa.Events
  alias Sarissa.EventStore.Writer

  # setup [:new_channel]
  test_channel()

  defmodule SimpleEvolver do
    use Sarissa.Evolver
    alias Sarissa.Events

    @impl Sarissa.Evolver
    def handle_event(%Events.EventA{}, state), do: state + 1
  end

  defmodule QueryDeciderEvolver do
    use Sarissa.Decider, [:id]
    use Sarissa.Evolver
    alias Sarissa.Context
    alias Sarissa.Events

    @impl Sarissa.Evolver
    def initial_context(_opts) do
      Context.new(state: 0)
    end

    @impl Sarissa.Evolver
    def handle_event(%Events.EventA{}, state), do: state + 1

    @impl Sarissa.Decider
    def decide(%__MODULE__{} = query, state) do
      {:read, {query.id, state}}
    end
  end

  test "reads stream and updates context" do
    events = [
      %Events.EventA{},
      %Events.EventA{},
      %Events.EventA{}
    ]

    assert 3 == SimpleEvolver.evolve(events, 0)
  end

  test "query decider evolver returns value", context do
    channel = context[:channel]

    events = [
      %Events.EventA{},
      %Events.EventA{},
      %Events.EventA{}
    ]

    query = %QueryDeciderEvolver{id: 2}

    {:ok, _channel} = Writer.write_events(channel, events)

    assert {:ok, {2, 3}} == Sarissa.Decider.execute(query, channel: context[:channel])
  end
end
