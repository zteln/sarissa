defmodule Sarissa.ProjectorTest do
  use ExUnit.Case, async: true
  import SarissaCase
  alias Sarissa.Events
  alias Sarissa.Context
  alias Sarissa.EventStore.Writer

  defmodule SimpleProjector do
    use Sarissa.Projector
    alias Sarissa.Context
    alias Sarissa.Events

    @impl Sarissa.Evolver
    def initial_context(_opts), do: Context.new(state: 0)

    @impl Sarissa.Evolver
    def handle_event(%Events.EventA{}, state), do: state + 1
  end

  test_channel()
  start_projector(SimpleProjector)

  test "projector can evolve state", context do
    events = [
      %Events.EventA{},
      %Events.EventA{},
      %Events.EventA{}
    ]

    {:ok, _channel} = Writer.write_events(context[:channel], events)

    assert_while do
      assert %Context{state: 3} = Sarissa.Projector.state(context[:projector])
    end
  end

  test "can unsubscribe and subscribe", context do
    assert :ok == Sarissa.Projector.unsubscribe(context[:projector])

    assert %Context{state: 0} = Sarissa.Projector.state(context[:projector])

    events = [
      %Events.EventA{},
      %Events.EventA{},
      %Events.EventA{}
    ]

    {:ok, channel} = Writer.write_events(context[:channel], events)

    assert :ok == Sarissa.Projector.catch_up(context[:projector])
    assert :ok == Sarissa.Projector.subscribe(context[:projector])

    assert %Context{state: 3} = Sarissa.Projector.state(context[:projector])

    {:ok, _channel} = Writer.write_events(channel, [%Events.EventA{}])

    assert_while do
      assert %Context{state: 4} = Sarissa.Projector.state(context[:projector])
    end
  end

  test "auto subscribes if subscriber exits", context do
    %{subscriber: subscriber} = :sys.get_state(context[:projector])

    {:ok, channel} = Writer.write_events(context[:channel], [%Events.EventA{}])

    assert_while do
      assert %Context{state: 1} = Sarissa.Projector.state(context[:projector])
    end

    Process.exit(subscriber, :exit)

    assert_while do
      %{subscriber: new_subscriber} = :sys.get_state(context[:projector])

      refute subscriber == new_subscriber
    end

    {:ok, _channel} = Writer.write_events(channel, [%Events.EventA{}])

    assert_while do
      assert %Context{state: 2} = Sarissa.Projector.state(context[:projector])
    end
  end
end
