defmodule FourOhFour.MixProject do
  use Mix.Project

  def project do
    [
      app: :four_oh_four,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: { FourOhFour.Application, [] },
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      { :component, path: "../.." },
    ]
  end
end
