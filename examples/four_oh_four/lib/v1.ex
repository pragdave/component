defmodule V1 do

  defmodule FourOhFour do
    def create() do
      %{}
    end

    def record_404(history, user, url) do
      Map.update(history, user, [ url ], &[ url | &1 ])
    end

    def for_user(history, user) do
      Map.get(history, user, [])
    end
  end

end
