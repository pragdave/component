defmodule V3 do

  defmodule FourOhFour do

    use GenServer

    @me __MODULE__

    def start_link(_) do
      GenServer.start_link(__MODULE__, %{}, name: @me)
    end

    def record_404(user, url) do
      GenServer.cast(@me, { :record_404, user, url })
    end

    def for_user(user) do
      GenServer.call(@me, { :for_user, user })
    end

    def init(empty_history) do
      { :ok, empty_history }
    end

    def handle_cast({ :record_404, user, url }, history) do
      new_history = Map.update(history, user, [ url ], &[ url | &1 ])
      { :noreply, new_history }
    end

    def handle_call({ :for_user, user }, _from, history) do
      result = Map.get(history, user, [])
      { :reply, result, history }
    end
  end

end
