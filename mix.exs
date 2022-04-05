#-------------------------------------------------------------------------------
# Author: Keith Brings
# Copyright (C) 2018 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

defmodule Noizu.MnesiaVersioning.Mixfile do
  use Mix.Project

  def project do
    [app: :noizu_mnesia_versioning,
     version: "0.1.10",
     elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env),
      package: package(),
     deps: deps(),
     description: "Schema Management Framework for Elixir/Amnesia",
     docs: docs()
   ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/fixtures"]
  defp elixirc_paths(_),     do: ["lib"]

  defp package do
    [
      maintainers: ["noizu"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/noizu/MnesiaVersioning"}
    ]
  end

  def application do
    [ applications: [:logger, :mnesia],
      extra_applications: [:amnesia]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.28.3", only: [:dev, :test], optional: true, runtime: false}, # Documentation Provider
      {:markdown, github: "devinus/markdown", only: [:dev], optional: true}, # Markdown processor for ex_doc
      {:amnesia, git: "https://github.com/noizu/amnesia.git", ref: "9266002"}, # Mnesia Wrapper
    ]
  end

  defp docs do
    [
      source_url_pattern: "https://github.com/noizu/MnesiaVersioning/blob/master/%{path}#L%{line}",
      extras: ["README.md", "markdown/config.md"]
    ]
  end

end
