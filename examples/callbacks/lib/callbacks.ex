defmodule Callbacks do

  use Component.Strategy.Dynamic,
      top_level: true,
      show_code: true,
      state_name: :count,
      initial_state: 0

  one_way record_event() do
    count + 1
  end

  callbacks do
    def init(s) do
      :timer.send_interval(5_000, :tick)
      { :ok, s }
    end

    def handle_info(:tick, count) do
      IO.puts "#{count} events in the last 5 seconds"
      { :noreply, 0 }
    end
  end
end
