defmodule Sarissa.Events.Metadata do
  @derive Jason.Encoder
  defstruct [:revision]

  def new(opts) do
    %__MODULE__{revision: opts[:revision] || 0}
  end
end
