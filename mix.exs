defmodule LiveCompile.MixProject do
  use Mix.Project

  def project do
    [
      app: :live_compile,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      description:
        "Lightning-fast ad-hoc data transformations in Livebook and IEx using dynamic JIT compilation.",
      docs: &docs/0,
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true}
    ]
  end
end
