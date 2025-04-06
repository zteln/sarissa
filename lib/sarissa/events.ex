defmodule Sarissa.Events do
  @type t :: struct()
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
    end
  end

  defmacro event(name, fields) do
    quote do
      contents =
        quote bind_quoted: [fields: unquote(fields)] do
          @derive {Jason.Encoder, only: fields}
          defstruct fields ++ [metadata: %{}]
          @type t :: %__MODULE__{}
        end

      mod_name = Module.concat(unquote(__MODULE__), unquote(name))
      Module.create(mod_name, contents, Macro.Env.location(__ENV__))
    end
  end

  @spec put_metadata(t(), atom(), term) :: t()
  def put_metadata(event, field, metadata) do
    metadata = Map.put(event.metadata, field, metadata)
    %{event | metadata: metadata}
  end

  @spec get_revision(t()) :: non_neg_integer() | :start | :any | {:error, :no_revision}
  def get_revision(%{metadata: %{revision: revision}}) do
    revision
  end

  def get_revision(_event), do: {:error, :no_revision}
end
