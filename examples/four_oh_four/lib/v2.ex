defmodule V2 do

  defmodule FourOhFour do

    use GenServer

    def start_link() do
      GenServer.start_link(__MODULE__, %{})
    end

    def record_404(pid, user, url) do
      GenServer.cast(pid, { :record_404, user, url })
    end

    def for_user(pid, user) do
      GenServer.call(pid, { :for_user, user })
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
