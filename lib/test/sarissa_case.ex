defmodule SarissaCase do
  defmacro gwt(context, g, w, t) do
    quote bind_quoted: [context: context, g: g, w: w, t: t] do
      if projector = context[:projector] do
        Sarissa.Projector.unsubscribe(projector)
      end

      channel = context[:channel] || raise "no :channel specified"

      {:ok, updated_channel} = Sarissa.EventStore.Writer.write_events(channel, g)

      if projector = context[:projector] do
        Sarissa.Projector.catch_up(projector)
        Sarissa.Projector.subscribe(projector)
      end

      result =
        case Sarissa.Decider.execute(w, Map.to_list(context)) do
          {:ok, %Sarissa.EventStore.Channel{}} ->
            {:ok, _channel, events} = Sarissa.EventStore.Reader.read_events(updated_channel)

            Enum.to_list(events)

          {:ok, result} ->
            result

          {:error, _} = error ->
            error
        end

      # TODO better assert (iterate through fields and match partially?)
      quote do
        assert match?(
                 unquote(Macro.escape(t)),
                 unquote(Macro.escape(result))
               )
      end
      |> Code.eval_quoted()
    end
  end

  defmacro test_channel do
    quote do
      setup context do
        name = to_string(context.module)
        id = Spear.Uuid.uuid_v4() |> String.replace("-", "")

        %{
          channel: Sarissa.EventStore.Channel.new(name, id: id)
        }
      end
    end
  end

  defmacro start_projector(projector) do
    quote do
      setup context do
        projector =
          start_link_supervised!(
            {unquote(projector), channel: context[:channel], name: context[:module]}
          )

        %{projector: projector}
      end
    end
  end

  defmacro assert_while(do: block) do
    quote do
      assert_while(500, fn -> unquote(block) end)
    end
  end

  def assert_while(0, f), do: f.()

  def assert_while(timeout, f) do
    try do
      f.()
    rescue
      ExUnit.AssertionError ->
        Process.sleep(10)
        assert_while(max(timeout - 10, 0), f)
    end
  end
end
