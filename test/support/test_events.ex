defmodule TestEvents do
  use Sarissa.Events

  event(EventA, [:a, :b])
  event(EventB, [:b, :c])
  event(EventC, [:c, :d])
end
