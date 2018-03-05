#-------------------------------------------------------------------------------
# Author: Keith Brings
# Copyright (C) 2018 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

defmodule Noizu.MnesiaVersioning.Test.SchemaProvider do
  alias Noizu.MnesiaVersioning.ChangeSet
  use Amnesia
  use Noizu.MnesiaVersioning.TestDatabase.TestTable
  use Noizu.MnesiaVersioning.TestDatabase.TestRecoveryTable
  use Noizu.MnesiaVersioning.SecondTestDatabase.SecondTestTable

  @behaviour Noizu.MnesiaVersioning.SchemaBehaviour

  def neighbors() do
    {:ok, nodes} = Noizu.MnesiaVersioning.Test.TopologyProvider.mnesia_nodes();
    nodes
  end

  #-----------------------------------------------------------------------------
  # ChangeSets
  #-----------------------------------------------------------------------------
  def change_sets do
    [
      %ChangeSet{
        changeset: "TestCreate",
        author: "noizu",
        note: "Insert Dummy Table",
        update: fn() ->
          if !Amnesia.Table.exists?(Noizu.MnesiaVersioning.TestDatabase.TestTable) do
            :ok = Noizu.MnesiaVersioning.TestDatabase.TestTable.create(disk: neighbors())
          end
          if !Amnesia.Table.exists?(Noizu.MnesiaVersioning.SecondTestDatabase.SecondTestTable) do
            :ok = Noizu.MnesiaVersioning.SecondTestDatabase.SecondTestTable.create(disk: neighbors())
          end

          :success
        end,

        rollback: fn() ->
          Noizu.MnesiaVersioning.TestDatabase.TestTable.wait()
          Noizu.MnesiaVersioning.SecondTestDatabase.SecondTestTable.wait()

          :ok = Noizu.MnesiaVersioning.TestDatabase.TestTable.destroy()
          :ok = Noizu.MnesiaVersioning.SecondTestDatabase.SecondTestTable.destroy()

          :removed
        end
      },
      %ChangeSet{
        changeset: "TestByChangeSet",
        author: "noizu",
        note: "Insert Dummy Table",
        update: fn() ->
          Noizu.MnesiaVersioning.SecondTestDatabase.SecondTestTable.wait()
          Amnesia.Fragment.transaction do
            %Noizu.MnesiaVersioning.SecondTestDatabase.SecondTestTable{
              identifier: 1,
              value: "TestRefByChangeSet"
            } |> Noizu.MnesiaVersioning.SecondTestDatabase.SecondTestTable.write
            :success
          end
        end,

        rollback: fn() ->
          Noizu.MnesiaVersioning.SecondTestDatabase.SecondTestTable.wait()
          Amnesia.Fragment.transaction do
            Noizu.MnesiaVersioning.SecondTestDatabase.SecondTestTable.delete(1)
            :removed
          end
        end
      },
      %ChangeSet{
        changeset: "TestPopulate",
        author: "noizu",
        note: "Insert some records in dummy table.",
        update: fn() ->
          Noizu.MnesiaVersioning.TestDatabase.TestTable.wait()

          Amnesia.Fragment.transaction do
            %Noizu.MnesiaVersioning.TestDatabase.TestTable{
              identifier: 1,
              value: "Hello World"
            } |> Noizu.MnesiaVersioning.TestDatabase.TestTable.write
            :success
          end
        end,

        rollback: fn() ->
          Noizu.MnesiaVersioning.TestDatabase.TestTable.delete(1)
          :removed
        end
      },
      %ChangeSet{
        changeset: "TestUpdate",
        author: "noizu",
        note: "Update a records in dummy table. This tests what a major schema overhaul with recovery support might look like in a real changeset.",
        update: fn() ->
          Noizu.MnesiaVersioning.TestDatabase.TestTable.wait()

          # Setup recovery table
          if !Amnesia.Table.exists?(Noizu.MnesiaVersioning.TestDatabase.TestRecoveryTable) do
            :ok = Noizu.MnesiaVersioning.TestDatabase.TestRecoveryTable.create(disk: neighbors())
          end

          Amnesia.Fragment.transaction do
            # Get current
            existing = Noizu.MnesiaVersioning.TestDatabase.TestTable.read(1)

            # Insert into recovery table
            %Noizu.MnesiaVersioning.TestDatabase.TestRecoveryTable{identifier: {:ref, Noizu.MnesiaVersioning.TestDatabase.TestTable, existing.identifier}, value: existing}
              |> Noizu.MnesiaVersioning.TestDatabase.TestRecoveryTable.write()

            # Update existing
            %Noizu.MnesiaVersioning.TestDatabase.TestTable{existing| value: "Goodbye World"}
              |> Noizu.MnesiaVersioning.TestDatabase.TestTable.write
          end
          :success
        end,

        rollback: fn() ->
          # Wait for tables
          Noizu.MnesiaVersioning.TestDatabase.TestTable.wait()
          Noizu.MnesiaVersioning.TestDatabase.TestRecoveryTable.wait()

          Amnesia.Fragment.transaction do
            # restore previous value
            recovery = Noizu.MnesiaVersioning.TestDatabase.TestRecoveryTable.read({:ref, Noizu.MnesiaVersioning.TestDatabase.TestTable, 1})
            recovery.value |> Noizu.MnesiaVersioning.TestDatabase.TestTable.write
          end

          # remove temporary recovery table used for storing original table entries.
          :ok = Noizu.MnesiaVersioning.TestDatabase.TestRecoveryTable.destroy()

          :removed
        end
      },
    ]
  end

end # End Mix.Task.Migrate
