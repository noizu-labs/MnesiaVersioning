#-------------------------------------------------------------------------------
# Author: Keith Brings <keith.brings@noizu.com>
# Copyright (C) 2017 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

defmodule Noizu.MnesiaVersioning.Tasks.Install do
  @moduledoc """
  User must specify the underling schema(s) maintained by this library in their
  config.exs file under  :noizu_mnesia_versioning, :databases [DatabaseName]

  User must additionally specify provider method that implements
  the Noizu.MnesiaVersioning.TopologyBehaviour behaviour under :noizu_mnesia_versioning, topology_provider: YourTopologyProvider

  @see doc for example implementation.

  This tasks insures all nodes are online and then proceeds to register schema and necessary noizu mnesia versioning tables.

  """
  require Logger

  defmacro __using__(options) do
    topology_provider = Dict.get(options, :topology_provider, Application.get_env(Noizu.MnesiaVersioning, :topology_provider, :required_setting))
    if topology_provider == :required_setting do
      Logger.error "MnesiaVersioningInit - To use the Noizu.MnesiaVersioning library you must specify a topology_provider option in the noizu_mnesia_versioning config section. For more details @see mnesia_versioning/doc/config.md"
      raise "Noizu.MnesiaVersioning :topology_provider setting not configured. @see mnesia_versioning/doc/config.md for more details."
    end
    quote do
      require Amnesia
      require Amnesia.Helper
      require Logger
      use Noizu.MnesiaVersioning
      use Mix.Task
      import unquote(__MODULE__)

      def main(args) do
        run(args)
      end #end main/1

      def run(_) do
        {:ok, nodes} = unquote(topology_provider).mnesia_nodes()
        Logger.info "MnesiaVersioningInit - Configuring Schema on specified nodes: #{inspect nodes}"

        case Amnesia.Schema.create(nodes)  do
          :ok ->
            Logger.info "MnesiaVersioningInit - Schema created, proceeding to populate versioning tables."
            setup_versioning_tables(nodes)
            :ok
          _ ->
            Logger.warn "MnesiaVersioningInit - Schema appears to already exit. Proceeding . . . unexected outcomes may occur."
            setup_versioning_tables(nodes)
            :ok
        end
      end # end def run/1

      def setup_versioning_tables(nodes) do
        npids = for (n <- nodes) do
          pid = Node.spawn(n, __MODULE__, :wait_for_init, [self()])
          receive do
            :wait_mode -> :wait_mode
          end
          pid
        end
        Logger.info "MnesiaVersioningInit - Installing Versioning Table"
        attempt_create = Noizu.MnesiaVersioning.create(disk: nodes)
        Logger.info "MnesiaVersioningInit - Schema Create: #{inspect attempt_create}"
        Logger.info "MnesiaVersioningInit - Noizu.MnesiaVersioning.wait()"
        attempt_wait = Noizu.MnesiaVersioning.wait()
        Logger.info "MnesiaVersioningInit - Schema Wait: #{inspect attempt_wait}"
        for (n <- npids) do
          send n, :initilization_complete
          receive do
            :initilization_complete_confirmed -> :ok
          end
        end
        Logger.info "MnesiaVersioningInit -Initilization Complete."
        :fin
      end # end set_versioning_tables/1

      def wait_for_init(caller) do
        Logger.info "MnesiaVersioningInit #{inspect node()} - Wait For Init"
        amnesia_start = Amnesia.start
        Logger.info "MnesiaVersioningInit #{inspect node()} - Amnesia Start: #{inspect amnesia_start}."
        Logger.info "Send wait_mode confirmation"
        send caller, :wait_mode

        Logger.info "MnesiaVersioningInit #{inspect node()} - Wait for :initilization_complete response"
        receive do
          :initilization_complete ->
            Logger.info "MnesiaVersioningInit #{inspect node()} - Initilization Complete, stopping Amnesia"
            Amnesia.stop
            send caller, :initilization_complete_confirmed
            :ok
        end
      end # end wait_for_init/1

    end # end qoute do
  end # end using
end # end Mix.Tasks.MnesaVersioningInit
