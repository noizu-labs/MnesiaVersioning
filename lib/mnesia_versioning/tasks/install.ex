#-------------------------------------------------------------------------------
# Author: Keith Brings <keith.brings@noizu.com>
# Copyright (C) 2017 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

defmodule Noizu.MnesiaVersioning.Tasks.Install do
  @moduledoc """
  The Install Tasks creates the initial Mnesia schema and inserts the necessary record keeping tables for tracking schema versioning.
  If you already have an existing schema you may run with the `--skip-schema` option to only insure the tracking tables are created.
  This tasks will connect to all mnesia nodes specified by your `:topology_provider.mnesia_nodes` method. If you are running as a single
  unnamed node simply return a nil or empty list [] value in your mnesia_nodes implementation.

  Currently to use this task a user much implement a Mix.Tasks.Install (or similiarly named)
  module and load the Noizu Implementation with a use statement.

  *Note*
  If installing on multiple mnesia nodes, all nodes must be running and reachable for this script to function correctly.
  This may be done by simply running `MIX_ENV=%target% iex --name=%node_name% -S mix install wait` on all instances other than the one
  on which you will be running `MIX_ENV=%target% iex --name=%node_name% -S mix install [--skip-schema]`

  *Example*
  ```
  defmodule Mix.Tasks.Install do
    use Noizu.MnesiaVersioning.Tasks.Install
  end
  ```

  *Usage*
  || Command                                     || Notes                                                ||  Example                                                      ||
  | `mix install`                                 | Setup Schema and versioning table                     | `mix install`                                                  |
  | `mix install --skip-schema`                   | Setup versioning table only.                          | `mix install --skip-schema`                                    |

  *Configuration*
  The user must provide modules that implement the `Noizu.MnesiaVersioning.SchemaBehaviour` and `Noizu.MnesiaVersioning.TopologyBehaviour` behaviours.
  The providers may be specified in the user's config file or as options to the use Noizu.MnesiaVersioning.Tasks.Migrate task.
  The user may additionally choose to use a database other than Noizu.MnesiaVersioning.DAtabase for tracking schema versioning by insuring it is created/creatable and passing as a option to this command, or as a config paramater.

  *Configration Example: config.exs*
  ```
    config Noizu.MnesiaVersioning,
      topology_provider: MyApp.Mnesia.TopologyProvider,
      schema_provider: MyApp.Mnesia.SchemaProvider
  ```

  *Configration Example: using arguments*
  ```
    defmodule Mix.Tasks.Install do
      use Noizu.MnesiaVersioning.Tasks.Install,
        topology_provider: MyApp.Mnesia.AlternativeTopologyProvider,
        schema_provider: MyApp.Mnesia.AlternativeSchemaProvider
    end
  ```
  """

  defmacro __using__(options) do
    versioning_table = Keyword.get(options, :versioning_table, Application.get_env(Noizu.MnesiaVersioning, :versioning_table, Noizu.MnesiaVersioning.Database))
    topology_provider = Keyword.get(options, :topology_provider, Application.get_env(Noizu.MnesiaVersioning, :topology_provider, :required_setting))
    if topology_provider == :required_setting do
      IO.puts  "#{__MODULE__} - To use the Noizu.MnesiaVersioning library you must specify a topology_provider option in the noizu_mnesia_versioning config section. For more details @see mnesia_versioning/doc/config.md"
      raise "Noizu.MnesiaVersioning :topology_provider setting not configured. @see mnesia_versioning/doc/config.md for more details."
    end

    quote do
      require Amnesia
      require Amnesia.Helper

      use unquote(versioning_table)
      use Mix.Task

      import unquote(__MODULE__)


      def run(["wait"]) do
        :ok
      end

      def run(["--skip-schema"]) do
        IO.puts "#{__MODULE__} - Skipping Schema Creation . . . Proceeding to create versioning tables."
        nodes = case unquote(topology_provider).mnesia_nodes() do
          {:ok, nil} -> [node()]
          {:ok, []} -> [node()]
          {:ok, nodes} -> nodes
        end

        setup_versioning_tables(nodes)
      end

      def run([]) do
        nodes = case unquote(topology_provider).mnesia_nodes() do
          {:ok, nil} -> [node()]
          {:ok, []} -> [node()]
          {:ok, nodes} -> nodes
        end

        IO.puts  "#{__MODULE__} - Configuring Schema on specified nodes: #{inspect nodes}"
        case Amnesia.Schema.create(nodes) do
          :ok ->
            IO.puts  "#{__MODULE__} - Schema created . . . Proceeding to create versioning tables."
            setup_versioning_tables(nodes)
          _ ->
            IO.puts "#{__MODULE__} - Schema appears to already exit . . . Proceeding to create versioning tables (unexected outcomes may occur)."
            setup_versioning_tables(nodes)
        end # end case Schema.create
      end # end def run/1

      def run(_) do
        IO.puts """
        Usage:
        mix install
        mix install wait
        mix install --skip-schema
        """
        :error
      end

      def setup_versioning_tables(nodes) do
        npids = for (n <- nodes) do
          pid = Node.spawn(n, __MODULE__, :wait_for_init, [self()])
          receive do
            :wait_mode -> :wait_mode
          end
          pid
        end
        IO.puts  "#{__MODULE__} - Installing Versioning Table"
        attempt_create = unquote(versioning_table).create(disk: nodes)
        IO.puts  "#{__MODULE__} - Schema Create: #{inspect attempt_create}"
        IO.puts  "#{__MODULE__} - unquote(versioning_table).wait()"
        attempt_wait = unquote(versioning_table).wait()
        IO.puts  "#{__MODULE__} - Schema Wait: #{inspect attempt_wait}"
        for (n <- npids) do
          send n, :initilization_complete
          receive do
            :initilization_complete_confirmed -> :ok
          end # end recieve
        end # end for npids
        IO.puts  "#{__MODULE__} -Initilization Complete."
        :ok
      end # end set_versioning_tables/1

      def wait_for_init(caller) do
        IO.puts  "#{__MODULE__} #{inspect node()} - Wait For Init"
        amnesia_start = Amnesia.start
        IO.puts  "#{__MODULE__} #{inspect node()} - Amnesia Start: #{inspect amnesia_start}."
        IO.puts  "Send wait_mode confirmation"
        send caller, :wait_mode

        IO.puts  "#{__MODULE__} #{inspect node()} - Wait for :initilization_complete response"
        receive do
          :initilization_complete ->
            IO.puts  "#{__MODULE__} #{inspect node()} - Initilization Complete, stopping Amnesia"
            Amnesia.stop
            send caller, :initilization_complete_confirmed
            :ok
        end # end recieve
      end # end wait_for_init/1
    end # end qoute do
  end # end using
end # end Mix.Tasks.MnesaVersioningInit
