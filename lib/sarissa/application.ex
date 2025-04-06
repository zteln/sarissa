defmodule Sarissa.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  # TODO remove
  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        # Starts a worker by calling: Sarissa.Worker.start_link(arg)
        # {Sarissa.Worker, arg}
      ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Sarissa.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
