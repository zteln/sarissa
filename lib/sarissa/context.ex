defmodule Sarissa.Context do
  defstruct [:channel, :state]
  @type t :: %__MODULE__{}

  def new(opts \\ []) do
    %__MODULE__{channel: opts[:channel], state: opts[:state]}
  end
end
