defmodule Sarissa.EventStore.ChannelTest do
  use ExUnit.Case, async: true
  alias Sarissa.EventStore.Channel

  test "new/2" do
    assert %Channel{name: "stream-123", revision: :start} == Channel.new("stream", id: 123)

    assert %Channel{name: "$ce-stream", revision: 2} ==
             Channel.new("stream", type: :by_category, revision: 2)

    assert %Channel{name: "stream-123", filter: nil, revision: :start} ==
             Channel.new("stream", id: 123, filter_by: ~r/foo/)

    assert %Channel{name: :all, filter: %Spear.Filter{}, revision: :start} =
             Channel.new(:all, filter_by: ~r/foo/)
  end

  test "update_revision/2" do
    channel = Channel.new("stream", id: 123)

    assert %Channel{name: "stream-123", revision: 0} == Channel.update_revision(channel, 0)
  end

  test "update_revision_with/2" do
    channel = Channel.new("stream", id: 123)

    assert %Channel{name: "stream-123", revision: 0} ==
             Channel.update_revision_with(channel, 1)

    channel = %{channel | revision: 1}

    assert %Channel{name: "stream-123", revision: 3} ==
             Channel.update_revision_with(channel, 2)
  end
end
