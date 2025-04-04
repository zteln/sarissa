defmodule Sarissa.EventStore.Channel do
  defstruct [
    :name,
    :revision
  ]

  @type t :: %__MODULE__{}

  @spec new(name :: String.t(), opts :: keyword) :: t()
  def new(name, opts \\ []) do
    %__MODULE__{}
    |> name(name, opts)
    |> revision(opts)
  end

  @spec update_revision(channel :: t(), revision :: non_neg_integer | :start) :: t()
  def update_revision(channel, revision) do
    %{channel | revision: revision}
  end

  @spec update_revision_with(channel :: t(), with :: non_neg_integer) :: t()
  def update_revision_with(channel, with) do
    revision =
      if channel.revision == :start do
        # TODO +/-1 ??
        # with - 1
        with
      else
        channel.revision + with
      end

    update_revision(channel, revision)
  end

  defp name(channel, name, opts) do
    cond do
      name == :all -> %{channel | name: name}
      not is_nil(opts[:id]) -> %{channel | name: "#{name}-#{opts[:id]}"}
      opts[:type] == :by_category -> %{channel | name: "$ce-#{name}"}
      opts[:type] == :by_event_type -> %{channel | name: "$et-#{name}"}
      true -> raise "no valid names or types for channel"
    end
  end

  defp revision(channel, opts) do
    if revision = opts[:revision] do
      %{channel | revision: revision}
    else
      %{channel | revision: :start}
    end
  end
end
