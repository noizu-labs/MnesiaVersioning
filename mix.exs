defmodule Noizu.MnesiaVersioning.Mixfile do
  use Mix.Project

  def project do
    [app: :noizu_mnesia_versioning,
     version: "0.1.2",
     elixir: "~> 1.4",
     package: package(),
     deps: deps(),
     description: "Schema Management Framework for Elixir/Amnesia",
     docs: docs()
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
      {:ex_doc, "~> 0.11", only: [:dev], optional: true, only: [:dev]}, # Documentation Provider
      {:markdown, github: "devinus/markdown", only: [:dev], optional: true}, # Markdown processor for ex_doc
      {:amnesia, git: "https://github.com/meh/amnesia.git", ref: "87d8b4f"}, # Mnesia Wrapper
    ]
  end

  defp docs do
  [
    source_url_pattern: "https://github.com/noizu/MnesiaVersioning/blob/master/%{path}#L%{line}",
    extras: ["README.md", "markdown/config.md"]
  ]
end

end
