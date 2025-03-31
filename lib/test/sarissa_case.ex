defmodule SarissaCase do
  defmacro gwt(context, g, w, t) do
    quote bind_quoted: [context: context, g: g, w: w, t: t] do
      # TODO
      # If {:ok, channel} then result = read_events (a command)
      # else result from {:ok, result} (a query)
      # assert result == t
    end
  end
end
