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

  * `service_name:`

    The name to give the component. Defaults to the module name.

  * `default_concurrency:`

    The number of worker processes started by `consume`.. Defaults to
    the number of active schedulers on the node running the component.
    This can be overridden on a per-call basis by passing it as an
    option to `consume`.

  * `default_timeout:`

    The overall processing timeout. Defaults to 5,000mS. This can be
    overridden on a per-call basis by passing it as an option to
    `consume`.

  * `default_ordered:`

     If truthy, results will be returned in the same order as inputs. If
     this isn't a requirement, you'll sometimes get less delay between
     results by setting this to false.

  * `show_code:` Dumps the generated code to STDOUT if truthy.

  ### Invoking The Hungry Servers

  Use the target module's `consume` function to kick off the processing
  by the hungry servers. It takes an enumerable or a stream. The hungry
  servers take entries from this collection and process them, returning
  a list of the results.

  The `consume` function takes options as its second parameter which
  override any the defaults given in the `use Component.Strategy.Hungry`
  call:

  * `timeout:` _nnn_

     Set the timeout for this particular call

  * `concurrency:`

     How many workers will consume this resource.

  * `ordered:`  _true_ | _false_

     Whether results are returned in the same order as the inputs.

  * `into:`

     The `into:` option determines how the results are returned.

     * `[ ]`, `%{ }`

       Return a list or map when the workers all finish.

     * `:stream`

       Immediate return a stream of the results. Results will become
       available on this stream as they are produced.

     * `fn val -> ... end`

       Invoke the given function for each result as it becomes
       available, passing it the result.

  * `when_done:` _fn result -> ... end_

    Invoke the function when all processing is complete. It is passed
    the result of the computation.

  ### Synchronous vs. Asynchronous

  A call to `consume` which returns a reified result (for example a list
  or a map) is always synchronous. If you don't override anything, this
  willbe the case, as the result is returned as a list.

  If the `into:` parameter specifies `:stream` or a function, then
  `consume` might return before the workers have finished. In this case
  values willbe made available to the streasm or function as they become
  available. The `when_done:` callback can then be used to determine
  when processing is complete.

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

  HungryAdder.initialize()
  HungryAdder.consume([1,2,"cat"])   # ->  [ 3, 6, "catcat" ]
  HungryAdder.consume(a: :b, c: :d)  #     [ b: :a, d: :c ]
  HungryAdder.consume(1..100, timeout: 300)        #     [ 3, 6, 9, ... ]
  ~~~
  """

 ########################################################################
 # Implementation note: This strategy is different enough from global   #
 # and dynamic that it doesn't need to have the Strategy behaviour: it  #
 # is totally self-contained.                                           #
 ########################################################################



  defmacro __using__(opts \\ []) do
    generate_hungry_service(__CALLER__.module, opts)
  end

  defp generate_hungry_service(caller, opts) do
    default_concurrency = opts[:default_concurrency] || System.schedulers_online()
    default_timeout     = opts[:default_timeout]     || 5000
    default_ordered     = opts[:default_ordered]     || true

    name = opts[:name] || caller

    quote do

      def initialize() do
        Task.Supervisor.start_link(name: unquote(name))
      end

      def consume(feed, options \\ []) do
        opts = [
          max_concurrency: options[:concurrency] || unquote(default_concurrency),
          timeout:         options[:timeout]     || unquote(default_timeout),
          ordered:         options[:ordered]     || unquote(default_ordered),
        ]

        into = Keyword.get(options, :into, [])

        Task.async_stream(feed, &process/1, opts)
        |> Stream.map(fn { :ok, val } -> val end)
        |> Component.Strategy.Common.forward_stream(into, options[:when_done])

      end
    end
  end
end
