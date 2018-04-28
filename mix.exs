defmodule Component.MixProject do
  use Mix.Project

  def project do
    [
      app:     :component,
      version: "0.1.0",
      elixir:  "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {
        Component.Application, []
      },
      extra_applications: [
        :logger
      ]
    ]
  end

  defp deps do
    [
      { :swarm,   "~> 3.3"   },
      { :statix,  ">= 1.0.0" },
    ]
  end
end
