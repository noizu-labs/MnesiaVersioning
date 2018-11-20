#-------------------------------------------------------------------------------
# Author: Keith Brings
# Copyright (C) 2018 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

defmodule Noizu.MnesiaVersioning.Tasks.Migrate do
  @moduledoc """
    The Migrate Tasks allows a user to apply or rollback changesets.
    Currently to use this task a user much implement a Mix.Tasks.Migrate (or similiarly named)
    module and load the Noizu Implementation with a use statement.

    *Example*
    ```
    defmodule Mix.Tasks.Migrate do
      use Noizu.MnesiaVersioning.Tasks.Migrate
    end
    ```

    *Usage*
    || Command                                     || Notes                                                    ||  Example                                                      ||
    | `mix migrate`                                 | Apply any unapplied changesets for current environment    | `mix migrate`                                                  |
    | `mix migrate count %count%`                   | Apply specified number of unapplied changesets            | `mix migrate count 5`                                          |
    | `mix migrate change %set% %author%`           | Apply a specific changeset by id and author.              | `mix migrate change "New User Tables" "Keith Brings"`          |
    | `mix migrate rollback count %count%`          | Rollback specified number of changesets.                  | `mix migrate rollback count 5`                                 |
    | `mix migrate rollback change %set% %author%"` | Rollback specific changeset by name and author.           | `mix migrate rollback change "New User Tables" "Keith Brings"` |

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
      defmodule Mix.Tasks.Migrate do
        use Noizu.MnesiaVersioning.Tasks.Migrate,
          topology_provider: MyApp.Mnesia.AlternativeTopologyProvider,
          schema_provider: MyApp.Mnesia.AlternativeSchemaProvider
      end
    ```
  """
  defmacro __using__(options) do
    versioning_table = Keyword.get(options, :versioning_table, Application.get_env(:noizu_mnesia_versioning, :versioning_table, Noizu.MnesiaVersioning.Database))
    silent = Keyword.get(options, :silent, Application.get_env(:noizu_mnesia_versioning, :silent, false))
    topology_provider = Keyword.get(options, :topology_provider, Application.get_env(:noizu_mnesia_versioning, :topology_provider, :required_setting))
    schema_provider = Keyword.get(options, :schema_provider, Application.get_env(:noizu_mnesia_versioning, :schema_provider, :required_setting))

    if topology_provider == :required_setting do
      if (!silent), do: IO.puts  "MnesiaVersioningInit - To use the Noizu.MnesiaVersioning library you must specify a topology_provider option in the noizu_mnesia_versioning config section. For more details @see mnesia_versioning/doc/config.md"
      raise "Noizu.MnesiaVersioning :topology_provider setting not configured. @see mnesia_versioning/doc/config.md for more details."
    end

    if schema_provider == :required_setting do
      if (!silent), do: IO.puts  "MnesiaVersioningInit - To use the Noizu.MnesiaVersioning library you must specify a schema_provider option in the noizu_mnesia_versioning config section. For more details @see mnesia_versioning/doc/config.md"
      raise "Noizu.MnesiaVersioning :schema_provider setting not configured. @see mnesia_versioning/doc/config.md for more details."
    end

    quote do
      alias Noizu.MnesiaVersioning.ChangeSet
      alias unquote(versioning_table).ChangeSets


      require Amnesia
      require Amnesia.Helper

      use Mix.Task
      use unquote(versioning_table)
      use unquote(versioning_table).ChangeSets

      import unquote(__MODULE__)

      def log(message) do
        if (!unquote(silent)), do: IO.puts(message)
      end

      def change_sets() do
        env = Application.get_env(:noizu_mnesia_versioning, :environment, :prod)
        unquote(schema_provider).change_sets() |> Enum.filter(
          fn(%ChangeSet{} = x) ->
              case x.environments do
                :all -> true
                supported when is_list(supported) -> Enum.member?(supported, env)
                supported when is_atom(supported) -> supported == env
                invalid -> raise "Invalid Changeset Environments Field Provided: #{inspect invalid}\n#{inspect x}"
              end
          end
        )
      end

      def run_command(:usage) do
        log "Usage:\n\tmix migrate\n\tmix migrate count %count%\n\tmix migrate change %set% %author%\n\tmix migrate rollback count %count%\n\tmix migrate rollback change %set% %author%"
      end #end run_command

      def run_command({:migrate, :count, count}) do
        Amnesia.start #
          unquote(versioning_table).ChangeSets.wait()
          migrate_count(change_sets(), count)
          spin_down(unquote(topology_provider).database())
        Amnesia.stop
      end #end run_command

      def run_command({:migrate, :change, change, author}) do
        Amnesia.start #
          unquote(versioning_table).ChangeSets.wait()
          h = change_sets()
            |> Enum.find(fn(x) -> {change, author} == {x.changeset, x.author} end)
          if h == :nil do
            log  "No such changeset exists: #{inspect {change, author}}"
          else
            # determine if entry has already been executed.
            record = Amnesia.transaction do
              unquote(versioning_table).ChangeSets.read({change, author})
            end # end Amnesia.transaction

            case record do
              :nil ->
                # No Entry, Apply and decrement count
                migrate_change(h, :apply, :new)
              record ->
                # skip unless pending
                case record.state do
                  :success -> migrate_change(h, :skip, record.state)
                  :pending -> migrate_change(h, :apply, record.state)
                  :failed -> migrate_change(h, :apply, record.state)
                  :error -> migrate_change(h, :apply, record.state)
                  :removed -> migrate_change(h, :apply, record.state)
                  _unknown ->
                    IO.puts "INVALID STATE FOUND: #{inspect record}"
                    migrate_change(h, :skip, record.state)
                end #end case record.state
            end # end case record
          end # end  if else h == :nil
          spin_down(unquote(topology_provider).database())
        Amnesia.stop
      end #end run_command

      def run_command({:rollback, :count, count}) do
        # Push last count success/failed/error changesets unto rollback list.
        # rollback.
        rollback = change_sets() |> Enum.reverse
        Amnesia.start #
          unquote(versioning_table).ChangeSets.wait()
          List.foldl(
            rollback,
            count,
            fn(h, acc) ->
              if acc == 0 do
                0 # short circuit
              else
                record = Amnesia.transaction do
                  unquote(versioning_table).ChangeSets.read({h.changeset, h.author})
                end # end Amnesia.transaction
                case record do
                  :nil ->
                    # No Entry, Apply and decrement count
                    rollback_change(h, :skip, :not_found)
                    acc
                  record ->
                    # skip unless pending
                    case record.state do
                      :success ->
                        rollback_change(h, :rollback, record.state)
                        acc - 1
                      :pending ->
                        rollback_change(h, :skip, record.state)
                        acc
                      :failed ->
                        rollback_change(h, :rollback, record.state)
                        acc - 1
                      :error ->
                        rollback_change(h, :rollback, record.state)
                        acc - 1
                      :removed ->
                        rollback_change(h, :skip, record.state)
                        acc

                      _unknown ->
                        IO.puts "INVALID STATE FOUND: #{inspect record}"
                        rollback_change(h, :skip, record.state)
                        acc
                    end #end case record.state
                  end #end case record
              end # end if else count == 0
            end # end List.foldl fn
          )
          spin_down(unquote(topology_provider).database())
        Amnesia.stop
      end #end run_command

      def run_command({:rollback, :change, change, author}) do
        Amnesia.start #
          unquote(versioning_table).ChangeSets.wait()
          h = change_sets()
            |> Enum.find(fn(x) -> {change, author} == {x.changeset, x.author} end)
          if h == :nil do
            log "No such changeset exists: #{inspect {change, author}}"
          else
            # determine if entry has already been executed.
            record = Amnesia.transaction do
              unquote(versioning_table).ChangeSets.read({change, author})
            end # end Amnesia.transaction

            case record do
              :nil ->
                # No Entry, Apply and decrement count
                rollback_change(h, :skip, :does_not_exist)
              record ->
                # skip unless pending
                case record.state do
                  :success -> rollback_change(h, :rollback, record.state)
                  :pending -> rollback_change(h, :skip, record.state)
                  :failed -> rollback_change(h, :rollback, record.state)
                  :error -> rollback_change(h, :rollback, record.state)
                  :removed -> rollback_change(h, :skip, record.state)
                  _unknown ->
                    IO.puts "INVALID STATE FOUND: #{inspect record}"
                     rollback_change(h, :skip, record.state)
                end #end case record.state
            end # end case record
          end # end  if else h == :nil
          spin_down(unquote(topology_provider).database())
        Amnesia.stop
      end #end run_command

      def migrate_count([], _count) do
        :success
      end #end migrate_count
      def migrate_count(_, 0) do
        :success
      end #end migrate_count

      def migrate_count([h|t], count) do
          # determine if entry has already been executed.
          key = {h.changeset, h.author}
          record = Amnesia.transaction do
            unquote(versioning_table).ChangeSets.read(key)
          end # end Amnesia.transaction

          case record do
            :nil ->
              # No Entry, Apply and decrement count
              migrate_change(h, :apply, :new)
              migrate_count(t, count - 1)
            _match ->
              # skip unless pending
              case record.state do
                :removed ->
                  migrate_change(h, :apply, :pending)
                  migrate_count(t, count - 1)
                :pending ->
                  migrate_change(h, :apply, :pending)
                  migrate_count(t, count - 1)
                _ ->
                  migrate_change(h, :skip, record.state)
                  migrate_count(t, count)
              end #end case record.state
          end # end case record
      end # end migrate_count


      #-----------------------------------------------------------------------------
      # Change Set Runner (upgrade)
      #-----------------------------------------------------------------------------

      def run(["init"]) do
        changesets = change_sets()
        #---------------------------------------------------------------------------
        # Changeset Runner Logic. -
        # Need precondition support to avoid applying unecesary changesets when
        # starting out with existing database.
        # @TODO Refine & Investigate
        #---------------------------------------------------------------------------
        Amnesia.start
          unquote(versioning_table).ChangeSets.wait()
          keys = get_available_change_sets()
          for change <- changesets do
            unquote(versioning_table).ChangeSets.wait()
            run_change_set(keys, change)
          end # end for change
          #spin_down(unquote(topology_provider).database())
        #Amnesia.stop
      end # end def run([])

      def run([command|arguments]) do
        instruction = case command do
          "count" ->
            case arguments do
              [count] ->
                {count, _} = Integer.parse(count)
                {:migrate, :count, count}
              _ -> :usage
            end #end case arguments

          "change" ->
            case arguments do
              [change|[author]] -> {:migrate, :change, change, author}
              _-> :usage
            end #end case arguments

          "rollback" ->
            [rollback_command|rollback_arguments] = arguments
            case rollback_command do
              "count" ->

                case rollback_arguments do
                  [count] ->
                    {count, _} = Integer.parse(count)
                    {:rollback, :count, count}
                  _ -> :usage
                end #end case rollback_arguments

              "change" ->
                case rollback_arguments do
                  [change|[author]] -> {:rollback, :change, change, author}
                  _-> :usage
                end #end case rollback_arguments
              _ -> :usage
            end #end case rollback_command
            _ -> :usage
        end #end case command
        run_command(instruction)
      end

      def migrate() do
        run([])
      end

      def rollback() do
        run(["rollback", "count", "999999"]) #@TODO cleaner implenentation
      end

      def run([]) do
        changesets = change_sets()
        #---------------------------------------------------------------------------
        # Changeset Runner Logic. -
        # Need precondition support to avoid applying unecesary changesets when
        # starting out with existing database.
        # @TODO Refine & Investigate
        #---------------------------------------------------------------------------
        Amnesia.start
          unquote(versioning_table).ChangeSets.wait()
          keys = get_available_change_sets()
          for change <- changesets do
            unquote(versioning_table).ChangeSets.wait()
            run_change_set(keys, change)
          end # end for change
          spin_down(unquote(topology_provider).database())
        Amnesia.stop
      end # end def run([])

      defp get_available_change_sets() do
        # Grab Changesets
        unquote(versioning_table).ChangeSets.wait()
        Amnesia.transaction do
          unquote(versioning_table).ChangeSets.keys()
        end # end Amnesia.transaction
      end # end get_available_change_sets

      defp rollback_change(changeset, stage, state) do
        log "
        --- Rollback [#{changeset.changeset}]@#{changeset.author} - #{inspect stage}
        change: [#{changeset.changeset}]@#{changeset.author}
        state: #{inspect state}
        note: #{changeset.note}
        --------------------------------------------------------------------------------
        "
        if(stage == :skip) do
          :ok
        else
          Amnesia.start
          outcome = changeset.rollback.()
          Amnesia.Fragment.transaction do
            unquote(versioning_table).ChangeSets.from_change_set(changeset, outcome)
              |> unquote(versioning_table).ChangeSets.write
          end # end Amnesia.transaction
        end # end if stage :skip
      end #end migrate_change()

      defp migrate_change(changeset, stage, state) do
        log "
        --- Migrate [#{changeset.changeset}]@#{changeset.author} - #{inspect stage} --
        change: [#{changeset.changeset}]@#{changeset.author}
        state: #{inspect state}
        note: #{changeset.note}
        --------------------------------------------------------------------------------
        "
        if(stage == :skip) do
          :ok
        else
          outcome = changeset.update.()

          outcome = case outcome do
            :success -> :success
            :failed -> :failed
            :removed -> :removed
            :pending -> :pending
            :error -> :error
            _ ->
              IO.puts "
              ChangeSet return invalid outcome: #{inspect outcome}

              "
              {:invalid_outcome, :outcome}
          end

          Amnesia.transaction do
          unquote(versioning_table).  ChangeSets.from_change_set(changeset, outcome)
              |> unquote(versioning_table).ChangeSets.write
          end # end Amnesia.transaction

        end # end if stage :skip
      end #end migrate_change()

      defp run_change_set(keys, changeset) do
        # Check if  ChangeSet already applied.
        key = {changeset.changeset, changeset.author}
        case Enum.find(keys, fn(x) -> x == key end) do
          :nil -> # No recrod exists.
            migrate_change(changeset, :apply, :new)
          _match -> # Record already exists. check to see if we may re-apply
            record = Amnesia.transaction do
              unquote(versioning_table).ChangeSets.read(key)
            end # end Amnesia.transaction
            proceed = rerun_change_set?(record)
            migrate_change(changeset, proceed, record.state)
        end # end case Enum.find
      end # end run_change_set(keys, changeset)

      defp rerun_change_set?(record) do
        case record.state do
          :success -> :skip
          :failed -> :skip
          :removed -> :apply
          :pending -> :apply
          _unknown ->
            IO.puts "INVALID STATE FOUND: #{inspect record}"
            :skip
        end # end case record.state
      end # end rerun_change_set?

      #-----------------------------------------------------------------------------
      # Helper Methods
      #-----------------------------------------------------------------------------
      defp spin_down(databases) when is_list(databases) do
        # Wait for defined tables to load in order to avoid erroneous ets insert records to show
        # after stopping Amnesia before completly loading a table.
        for database <- databases do
          tables = database.tables()
            |> Enum.filter(&(Amnesia.Table.exists?(&1)))

          not_available = database.tables()
            |> Enum.filter(&(!Amnesia.Table.exists?(&1)))

          case Amnesia.Table.wait(tables, 30_000) do
            :ok -> :ok
            err -> IO.puts """
============ Spin Down ==============
#{inspect err}
=====================================
            """
          end

          if not_available != [] do
            IO.puts """
============ Spin Down ==============
Not Created: #{inspect not_available}
=====================================
            """
          end

        end # end for databases
      end # end spin_down/1

      defp spin_down(database), do: spin_down([database])

      defp spin_up(databases) when is_list(databases) do
        # Wait for defined tables to load in order to avoid erroneous ets insert records to show
        # after stopping Amnesia before completly loading a table.
        for database <- databases do
          tables = database.tables()
            |> Enum.filter(&(Amnesia.Table.exists?(&1)))

          case Amnesia.Table.wait(tables, 30_000) do
            :ok -> :ok
            err -> IO.puts """
============ Spin Up ================
#{inspect err}
=====================================
            """
          end

        end # end for databases
      end # end spin_down/1

      defp spin_up(database), do: spin_up([database])


    end # end quote do
  end  # end using
end # end Mix.Tasks.MnesaVersioningInit
