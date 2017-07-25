#-------------------------------------------------------------------------------
# Author: Keith Brings <keith.brings@noizu.com>
# Copyright (C) 2017 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

defmodule Noizu.MnesiaVersioning.Tasks.Migrate do
  require Logger


  defmacro __using__(options) do
    topology_provider = Dict.get(options, :topology_provider, Application.get_env(Noizu.MnesiaVersioning, :topology_provider, :required_setting))
    if topology_provider == :required_setting do
      Logger.error "MnesiaVersioningInit - To use the Noizu.MnesiaVersioning library you must specify a topology_provider option in the noizu_mnesia_versioning config section. For more details @see mnesia_versioning/doc/config.md"
      raise "Noizu.MnesiaVersioning :topology_provider setting not configured. @see mnesia_versioning/doc/config.md for more details."
    end

    schema_provider = Dict.get(options, :schema_provider, Application.get_env(Noizu.MnesiaVersioning, :schema_provider, :required_setting))
    if schema_provider == :required_setting do
      Logger.error "MnesiaVersioningInit - To use the Noizu.MnesiaVersioning library you must specify a schema_provider option in the noizu_mnesia_versioning config section. For more details @see mnesia_versioning/doc/config.md"
      raise "Noizu.MnesiaVersioning :schema_provider setting not configured. @see mnesia_versioning/doc/config.md for more details."
    end

    quote do
      require Amnesia
      require Amnesia.Helper
      require Logger
      use Mix.Task
      use Noizu.MnesiaVersioning
      import unquote(__MODULE__)

      def main(args) do
        run(args)
      end

      def change_sets() do
        unquote(schema_provider).change_sets()
      end

      def run_command(:usage) do
        IO.puts "Usage:\n\tmix migrate\n\tmix migrate count %count%\n\tmix migrate change %set% %author%\n\tmix migrate rollback count %count%\n\tmix migrate rollback change %set% %author%"
      end #end run_command

      def run_command({:migrate, :count, count}) do
        Amnesia.start #
          Noizu.MnesiaVersioning.ChangeSets.wait()
          migrate_count(change_sets(), count)
          spin_down(unquote(topology_provider).database())
        Amnesia.stop
      end #end run_command

      def run_command({:migrate, :change, change, author}) do
        Amnesia.start #
          Noizu.MnesiaVersioning.ChangeSets.wait()
          h = change_sets()
            |> Enum.find(fn(x) -> {change, author} == {x.changeset, x.author} end)
          if h == :nil do
            Logger.error "No such changeset exists: #{inspect {change, author}}"
          else
            # determine if entry has already been executed.
            record = Amnesia.transaction do
              Noizu.MnesiaVersioning.ChangeSets.read({change, author})
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
          Noizu.MnesiaVersioning.ChangeSets.wait()
          List.foldl(
            rollback,
            count,
            fn(h, acc) ->
              if acc == 0 do
                0 # short circuit
              else
                record = Amnesia.transaction do
                  Noizu.MnesiaVersioning.ChangeSets.read({h.changeset, h.author})
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
          Noizu.MnesiaVersioning.ChangeSets.wait()
          h = change_sets()
            |> Enum.find(fn(x) -> {change, author} == {x.changeset, x.author} end)
          if h == :nil do
            IO.puts "No such changeset exists: #{inspect {change, author}}"
          else
            # determine if entry has already been executed.
            record = Amnesia.transaction do
              Ingressor.MnesiaVersioning.ChangeSets.read({change, author})
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
            Noizu.MnesiaVersioning.ChangeSets.read(key)
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

      def run([]) do
        changesets = change_sets()
        #---------------------------------------------------------------------------
        # Changeset Runner Logic. -
        # Need precondition support to avoid applying unecesary changesets when
        # starting out with existing database.
        # @TODO Refine & Investigate
        #---------------------------------------------------------------------------
        Amnesia.start
          Noizu.MnesiaVersioning.ChangeSets.wait()
          keys = get_available_change_sets()
          for change <- changesets do
            Noizu.MnesiaVersioning.ChangeSets.wait()
            run_change_set(keys, change)
          end # end for change
          spin_down(unquote(topology_provider).database())
        Amnesia.stop
      end # end def run([])

      defp get_available_change_sets() do
        # Grab Changesets
        Noizu.MnesiaVersioning.ChangeSets.wait()
        Amnesia.transaction do
          Noizu.MnesiaVersioning.ChangeSets.keys()
        end # end Amnesia.transaction
      end # end get_available_change_sets

      defp rollback_change(changeset, stage, state) do
        IO.puts "
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
            Noizu.MnesiaVersioning.ChangeSets.from_change_set(changeset, outcome)
              |> Noizu.MnesiaVersioning.ChangeSets.write
          end # end Amnesia.transaction
        end # end if stage :skip
      end #end migrate_change()

      defp migrate_change(changeset, stage, state) do
        IO.puts "
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
          Amnesia.transaction do
            Noizu.MnesiaVersioning.ChangeSets.from_change_set(changeset, outcome)
              |> Noizu.MnesiaVersioning.ChangeSets.write
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
              Noizu.MnesiaVersioning.ChangeSets.read(key)
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
        end # end case record.state
      end # end rerun_change_set?

      #-----------------------------------------------------------------------------
      # Helper Methods
      #-----------------------------------------------------------------------------
      defp spin_down(table) do
        # Wait for defined tables to load in order to avoid erroneous ets insert records to show
        # after stopping Amnesia before completly loading a table.
        tables = table.tables()
        for table <- tables do
          if(Amnesia.Table.exists?(table)) do
            Amnesia.Table.wait([table])
          end
        end
      end

    end # end quote do
  end  # end using
end # end Mix.Tasks.MnesaVersioningInit
