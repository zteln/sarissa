defmodule Sarissa.EventStore.Channel do
  defstruct [
    :name,
    :revision,
    :filter
  ]

  # TODO limit revision types? allow all?
  # How to handle event and checkpoint revision when incrementing?
  @type revision ::
          :start
          | :any
          | non_neg_integer
          | Spear.Event.t()
          | Spear.Filter.Checkpoint.t()

  @type t :: %__MODULE__{}

  @spec new(name :: String.t(), opts :: keyword) :: t()
  def new(name, opts \\ []) do
    %__MODULE__{}
    |> name(name, opts)
    |> revision(opts)
    |> filter(opts)
  end

  @spec update_revision(channel :: t(), revision) :: t()
  def update_revision(channel, revision) do
    %{channel | revision: revision}
  end

  @spec update_revision_with(channel :: t(), with :: non_neg_integer) :: t()
  def update_revision_with(channel, with) do
    revision =
      cond do
        # TODO how to handle :any ?
        # channel.revision in [:start, :any] -> with
        channel.revision == :start -> with - 1
        # channel.revision == :start -> with
        channel.revision == :any -> :any
        true -> channel.revision + with
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

  defp filter(%__MODULE__{name: :all} = channel, opts) do
    cond do
      match?(%Spear.Filter{}, opts[:filter]) ->
        %{channel | filter: opts[:filter]}

      match?(%Regex{}, opts[:filter_by]) ->
        filter_on = opts[:filter_on] || :stream_name
        filter_by = opts[:filter_by]
        filter_checkpoint_after = opts[:filter_checkpoint_after] || 1024

        filter = %Spear.Filter{
          on: filter_on,
          by: filter_by,
          checkpoint_after: filter_checkpoint_after
        }

        %{channel | filter: filter}

      true ->
        channel
    end
  end

  defp filter(channel, _opts), do: channel
end
