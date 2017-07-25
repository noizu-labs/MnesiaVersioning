defmodule Noizu.MnesiaVersioning.Mixfile do
  use Mix.Project

  def project do
    [app: :noizu_mnesia_versioning,
     version: "0.1",
     elixir: "~> 1.4",
     package: package(),
     deps: deps(),
     description: "Schema Management Framework for Elixir/Amnesia"
   ]
  end

  defp package do
    [
      maintainers: ["noizu"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/noizu/MnesiaVersioning"}
    ]
  end

  def application do
    [ applications: [:logger] ]
  end

  defp deps do
    [ { :ex_doc, "~> 0.11", only: [:dev] } ]
  end

end
