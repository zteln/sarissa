defmodule Sarissa.Projector do
  @moduledoc """
  `Sarissa.Projector` is a `GenServer` wrapper around `Sarissa.Evolver`.
  The callbacks from `Sarissa.Evolver` must be defined in the implementation.
  """

  @callback after_event(state :: term) :: term
  @callback save_checkpoint(checkpoint :: Spear.Event.t() | Spear.Filter.Checkpoint.t()) :: :ok

  defstruct [:context, :subscriber]

  def call(projector, call, timeout \\ 5000) do
    call!(projector, call, timeout)
  catch
    {:exit, {:timeout, _}} -> {:error, :timeout}
  end

  def call!(projector, call, timeout \\ 5000), do: GenServer.call(projector, call, timeout)

  def state(projector, timeout \\ 5000), do: call(projector, :get_projection_state, timeout)

  def catch_up(projector), do: call(projector, :catch_up)
  def subscribe(projector), do: call(projector, :subscribe)
  def unsubscribe(projector), do: call(projector, :unsubscribe)

  defmacro __using__(_opts) do
    quote do
      use Sarissa.Evolver
      use GenServer
      @behaviour unquote(__MODULE__)
      @before_compile unquote(__MODULE__)

      def start_link(opts) do
        GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
      end

      if Sarissa.Decider in Module.get_attribute(__MODULE__, :behaviour) do
        @impl Sarissa.Decider
        def context(_id, opts) do
          unquote(__MODULE__).state(opts[:projector])
        end

        defoverridable context: 2
      end

      @impl unquote(__MODULE__)
      def save_checkpoint(_checkpoint), do: :ok
      defoverridable save_checkpoint: 1

      @impl GenServer
      def init(opts) do
        Process.flag(:trap_exit, true)

        context = initial_context(opts)

        context = %{context | channel: opts[:channel] || context.channel}

        {:ok, %Sarissa.Projector{context: context}, {:continue, :evolve}}
      end

      @impl GenServer
      def handle_continue(:evolve, projection) do
        projection =
          projection
          |> catch_up()
          |> subscribe()

        {:noreply, projection}
      end

      @impl GenServer
      def handle_call(:get_projection_state, _from, projection) do
        {:reply, projection.context, projection}
      end

      def handle_call(:catch_up, _from, projection) do
        projection = catch_up(projection)
        {:reply, :ok, projection}
      end

      def handle_call(:subscribe, _from, projection) do
        projection = subscribe(projection)
        {:reply, :ok, projection}
      end

      def handle_call(:unsubscribe, _from, projection) do
        projection = unsubscribe(projection)
        {:reply, :ok, projection}
      end

      @impl GenServer
      def handle_info({:event, event}, projection) do
        context = projection.context
        revision = event.metadata.revision

        state =
          event
          |> handle_event(context.state)
          |> after_event()

        channel = Sarissa.EventStore.Channel.update_revision(context.channel, revision)
        context = %{context | state: state, channel: channel}

        {:noreply, %{projection | context: context}}
      end

      def handle_info({:checkpoint, checkpoint}, projection) do
        # TODO Wrap checkpoint? 
        :ok = save_checkpoint(checkpoint)
        {:noreply, projection}
      end

      def handle_info({:EXIT, _subscriber, :unsubscribe}, projection) do
        {:noreply, projection}
      end

      def handle_info({:EXIT, _subscriber, exit_reason}, projection) do
        projection = subscribe(projection)
        {:noreply, projection}
      end

      defp catch_up(projection) do
        context = projection.context
        {:ok, channel, events} = Sarissa.EventStore.Reader.read_events(context.channel)
        state = evolve(events, context.state)
        context = %{context | state: state, channel: channel}
        %{projection | context: context}
      end

      defp subscribe(projection) do
        context = projection.context

        {:ok, subscriber} =
          Sarissa.Subscriber.start_link(
            connector: self(),
            channel: context.channel
          )

        %{projection | subscriber: subscriber}
      end

      defp unsubscribe(projection) do
        Process.exit(projection.subscriber, :unsubscribe)
        %{projection | subscriber: nil}
      end
    end
  end

  defmacro __before_compile__(_opts) do
    quote do
      @impl unquote(__MODULE__)
      def after_event(state), do: state
    end
  end
end
