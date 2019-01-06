defmodule Component.Strategy.Hungry do

  @moduledoc """
  Implement a _hungry-consumer_ style worker.

  We feed the component a collection, and it maps it to another
  collection by passing each element through the `process` function.
  This processing occurs in parallel, up to a maximum concurrency you
  control. It is an efficient use of resources, as the scheduling is
  done automatically when each process finishes-there is no
  preallocation of elements to process.

  ### Options

  The `using Component.Strategy.Hungry` call takes the following
  options:

  * `name:`
    The name to give the component. Defaults to the module name.

  * `default_concurrency:`
    The number of worker processes to start. Defaults to the number of
    active schedulers on the node running the component.

  * `default_timeout:`
    The overall processing timeout. Defaults to 5,000mS

  * `show_code:`
    Dumps the generated code to STDOUT if truthy.

  ### Example

  ~~~ elixir
  defmodule HungryAdder do

    use Component.Strategy.Hungry,
        default_concurrency: 5

    def process(val) when is_number(val) do
      val * 3
    end

    def process(val) when is_binary(val) do
      val <> val
    end

    def process({a, b}), do: { b, a }
  end

  HungryAdderinitialize()
  HungryAdderconsume([1,2,"cat"])   # ->  [ 3, 6, "catcat" ]
  HungryAdderconsume(a: :b, c: :d)  #     [ b: :a, d: :c ]
  HungryAdderconsume(1..100)        #     [ 3, 6, 9, ... ]
  ~~~
  """
  alias Component.Strategy.Common

  defmacro __using__(opts \\ []) do
    generate_hungry_service(__CALLER__.module, opts)
  end

  defp generate_hungry_service(caller, opts) do
    default_concurrency = opts[:default_concurrency] || System.schedulers_online()
    default_timeout     = opts[:default_timeout]     || 5000
    name = opts[:name] || caller

    quote do

      def initialize() do
        Task.Supervisor.start_link(name: unquote(name))
      end

      def consume(feed, options \\ []) do
        opts = [
          max_concurrency: options[:concurrency] || unquote(default_concurrency),
          timeout:         options[:timeout]     || unquote(default_timeout)
        ]

        result = Task.async_stream(feed, &process/1, opts)
                 |> Enum.map(fn { :ok, val } -> val end)

        case options[:into] do
          nil ->
            result
          collectable ->
            result |> Enum.into(collectable)
        end
      end
    end
    |> Common.maybe_show_generated_code(opts)
  end
end
