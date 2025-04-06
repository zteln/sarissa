defmodule Sarissa.DeciderTest do
  use ExUnit.Case, async: true
  import SarissaCase
  alias Sarissa.Events
  alias Sarissa.EventStore.Reader

  defmodule SimpleCommand do
    use Sarissa.Decider, [:id]
    alias Sarissa.Context
    alias Sarissa.Events

    @impl Sarissa.Decider
    def context(_id, opts) do
      Context.new(channel: opts[:channel])
    end

    @impl Sarissa.Decider
    def decide(%__MODULE__{} = _command, _state) do
      {:write, [%Events.EventA{}]}
    end
  end

  defmodule SimpleQuery do
    use Sarissa.Decider, [:id]
    alias Sarissa.Context

    @impl Sarissa.Decider
    def context(_id, _opts) do
      Context.new(state: :a_state)
    end

    @impl Sarissa.Decider
    def decide(%__MODULE__{} = _command, state) do
      {:read, state}
    end
  end

  defmodule SimpleError do
    use Sarissa.Decider, [:id]
    alias Sarissa.Context

    @impl Sarissa.Decider
    def context(_id, _opts) do
      Context.new(state: :a_state)
    end

    @impl Sarissa.Decider
    def decide(%__MODULE__{} = _command, _state) do
      {:error, :reason}
    end
  end

  test_channel()

  test "command writes events", context do
    command = %SimpleCommand{id: 1}

    assert {:ok, _channel} = Sarissa.Decider.execute(command, channel: context[:channel])

    assert {:ok, _channel, events} = Reader.read_events(context[:channel])
    assert [%Events.EventA{}] = Enum.to_list(events)
  end

  test "query returns result" do
    query = %SimpleQuery{id: 1}
    assert {:ok, :a_state} = Sarissa.Decider.execute(query, [])
  end

  test "error is returned" do
    error = %SimpleError{id: 1}
    assert {:error, :reason} = Sarissa.Decider.execute(error, [])
  end
end
