ExUnit.start()

Supervisor.start_link([{Sarissa.EventStore, connection_string: "esdb://localhost:2114"}],
  strategy: :one_for_one
)
