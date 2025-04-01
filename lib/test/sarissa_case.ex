defmodule SarissaCase do
  defmacro gwt(context, g, w, t) do
    quote bind_quoted: [context: context, g: g, w: w, t: t] do
      if projection = context[:projection] do
        Sarissa.Projector.cancel_subscription(projection)
      end

      channel = context[:channel] || raise "no :channel specified"

      {:ok, updated_channel} = Sarissa.EventStore.Writer.write_events(channel, g)

      if projection = context[:projection] do
        Sarissa.Projector.catch_up(projection)
        Sarissa.Projector.start_subscription(projection)
      end

      result =
        case Sarissa.Decider.execute(w, channel: channel) do
          {:ok, %Sarissa.EventStore.Channel{}} ->
            updated_channel
            |> Sarissa.EventStore.Reader.read_events()
            |> Enum.to_list()

          {:ok, result} ->
            result

          {:error, _} = error ->
            error
        end

      quote do
        assert unquote(Macro.escape(t)) = unquote(Macro.escape(result))
      end
      |> Code.eval_quoted()
    end
  end

  def new_channel(context) do
    name = to_string(context.module)
    id = Spear.Uuid.uuid_v4()

    %{
      channel: Sarissa.EventStore.Channel.new(name, id: id)
    }
  end
end
