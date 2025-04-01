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
          defstruct fields ++ [:metadata]
          @type t :: %__MODULE__{}
        end

      mod_name = Module.concat(unquote(__MODULE__), unquote(name))
      Module.create(mod_name, contents, Macro.Env.location(__ENV__))
    end
  end
end
