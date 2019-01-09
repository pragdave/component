defmodule Component.MixProject do
  use Mix.Project

  @moduledoc """
  The component framework is meant to make it easy to decompose an
  application into many simple services. It does this by eliminating
  boilerplate code in common service patterns: source files can be just
  domain logic. See the GitHub repo for details.
  """


  def project do
    [
      app:     :component,
      version: "0.2.2",
      elixir:  "~> 1.6",
      deps:    deps(),
      description: @moduledoc,
      package:     package(),
      start_permanent: Mix.env() == :prod,
    ] ++ docs()
    end

    defp docs do
      [
        name:         "Component",
        source_url:   "https://github.com/pragdave/component",
        homepage_url: "https://github.com/pragdave/component",
        docs: [
          extras: [ "README.md" ],
          main:   "readme",
          logo:   "assets/color_puzzle_background_531533.png",
          assets: "assets",
        ]
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
      { :statix,  ">= 1.0.0" },
      { :poolboy, ">= 0.0.0" },
      { :ex_doc,  ">= 0.0.0", only: :dev },
    ]
  end

  defp package do
    [
      files: [
        "lib",
        "mix.exs",
        "README.md",
      ],
      contributors: [
        "Dave Thomas <dave@pragdave.me>",
      ],
      licenses: [
        "Same as Elixir"
      ],
      links: %{
        "GitHub" => "https://github.com/pragdave/component"
      },
    ]
  end

end
