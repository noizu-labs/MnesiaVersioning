defmodule Noizu.MnesiaVersioning.Mixfile do
  use Mix.Project

  def project do
    [app: :noizu_mnesia_versioning,
     version: "0.1.0",
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
    [
      {:lager, github: "basho/lager", tag: "3.2.4"},
      { :ex_doc, "~> 0.11", only: [:dev] },
      {:amnesia, git: "https://github.com/meh/amnesia.git", ref: "87d8b4f"}, # Mnesia Wrapper

    ]
  end

end
