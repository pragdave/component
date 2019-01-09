defmodule Callbacks.MixProject do
  use Mix.Project

  def project do
    [
      app: :callbacks,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: { Callbacks, [] },
      extra_applications: [
        :logger
      ],
    ]
  end

  defp deps do
    [
      { :component, path: "../.." },
    ]
  end
end
