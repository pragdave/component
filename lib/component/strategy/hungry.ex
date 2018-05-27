defmodule Component.Strategy.Hungry do

  alias Component.Strategy.Common

  defmacro __using__(opts \\ []) do
    generate_hungry_service(__CALLER__.module, opts)
  end

  defp generate_hungry_service(caller, opts) do
    default_worker_count = opts[:default_worker_count] || System.schedulers_online()
    name = opts[:name] || caller

    quote do

      def initialize() do
        Task.Supervisor.start_link(name: unquote(name))
      end

      def consume(feed, concurrency \\ unquote(default_worker_count)) do
        Task.async_stream(feed, &process/1, max_concurrency: concurrency)
        |> Enum.map(fn { :ok, val } -> val end)
      end
    end
    |> Common.maybe_show_generated_code(opts)
  end
end
