defmodule Component.CodeGenHelper do
  @moduledoc """
  Functions that help massage one- and two-way funtion definitions
  into real code. These are called from the Strategy@impl functions
  in the Strategy.Xxx modules.
  """

  @doc """
  If this component is top-level, generate the application stuff.
  """

  alias Component.Strategy.Common

  def maybe_create_application(options) do
    if options[:top_level] do
      quote do
        use Application

        def start(_type, _args) do
          children = [
            %{
              id: __MODULE__.Id,
              start: {__MODULE__, :wrapped_create, []}
            }
          ]

          opts = [strategy: :one_for_one, name: __MODULE__.Supervisor]
          IO.inspect(Supervisor.start_link(children, opts))
        end
      end
    else
      nil
    end
  end

  @doc false
  def generate_handle_call(options, {one_or_two_way, call, _body}) do
    request = call_signature(call, options)
    api_call = api_signature(options, call)
    state_var = {Common.state_name(options), [], nil}

    call_or_cast(one_or_two_way, request, state_var, api_call)
  end

  defp call_or_cast(:one_way, request, state_var, api_call) do
    quote do
      def handle_cast(unquote(request), șțąțɇ) do
        unquote(state_var) = șțąțɇ
        new_state = __MODULE__.Implementation.unquote(api_call)
        {:noreply, new_state}
      end
    end
  end

  defp call_or_cast(:two_way, request, state_var, api_call) do
    quote do
      def handle_call(unquote(request), _, șțąțɇ) do
        unquote(state_var) = șțąțɇ

        __MODULE__.Implementation.unquote(api_call)
        |> Common.create_genserver_response(șțąțɇ)
      end
    end
  end

  @doc false
  def generate_implementation(options, {_one_or_two_way, call, do: body}) do
    fix_warning =
      quote do
        _ = var!(unquote({Common.state_name(options), [], Elixir}))
        unquote(body)
      end

    quote do
      def(unquote(api_signature(options, call)), do: unquote(fix_warning))
    end
  end

  @doc false
  def api_signature(options, {name, context, args}) do
    no_state_args = args_without_state_or_defaults(args, options)

    {name, context, [{Common.state_name(options), [], nil} | no_state_args]}
  end


  def args_without_state(args, options) do
    state_name = Common.state_name(options)

    args
    |> Enum.reject(fn {name, _, _} -> name == state_name end)
    |> Enum.map(fn name -> var!(name) end)
  end

  def args_without_state_or_defaults(args, options) do
    args_without_state(args, options)
    |> remove_any_default_values()
  end

  defp remove_any_default_values(args) do
    args
    |> Enum.map(&remove_one_default/1)
  end

  # given def fred(a, b) return { :fred, a, b } (in quoted form)
  @doc false
  def call_signature({name, _, args}, options) do
    no_state_args = args_without_state_or_defaults(args, options)
    {:{}, [], [name | no_state_args]}
  end


  defp remove_one_default({:\\, _, [arg, _val]}), do: arg
  defp remove_one_default(arg), do: arg

end
