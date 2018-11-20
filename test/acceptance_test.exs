#-------------------------------------------------------------------------------
# Author: Keith Brings
# Copyright (C) 2018 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

defmodule AcceptanceTest do
  use ExUnit.Case, async: false
  use Amnesia
  use Noizu.MnesiaVersioning.TestDatabase.TestTable
  use Noizu.MnesiaVersioning.TestDatabase.TestRecoveryTable
  use Noizu.MnesiaVersioning.SecondTestDatabase.SecondTestTable

  setup do
    purge_schema()
  end

  defp assert_setup_schema() do
    Amnesia.stop
    {:ok, nodes} = Noizu.MnesiaVersioning.Test.TopologyProvider.mnesia_nodes()
    Amnesia.Schema.create(nodes)
    Amnesia.start
    assert Amnesia.Table.exists?(Noizu.MnesiaVersioning.Database.ChangeSets) == false
    Amnesia.stop
  end

  def purge_schema do
    Amnesia.stop
    Amnesia.Schema.destroy
  end

  test "Install Clean" do
    Noizu.MnesiaVersioning.Test.Install.run([])
    Amnesia.start
    assert Amnesia.Table.exists?(Noizu.MnesiaVersioning.Database.ChangeSets) == true
  end

  test "Install Existing Schema" do
    assert_setup_schema()
    Noizu.MnesiaVersioning.Test.Install.run([])
    Amnesia.start
    assert Amnesia.Table.exists?(Noizu.MnesiaVersioning.Database.ChangeSets) == true
  end

  test "Install Skip Schema" do
    assert_setup_schema()
    Noizu.MnesiaVersioning.Test.Install.run(["--skip-schema"])
    Amnesia.start
    assert Amnesia.Table.exists?(Noizu.MnesiaVersioning.Database.ChangeSets) == true
  end

  test "Migrate" do
    Noizu.MnesiaVersioning.Test.Install.run([])
    Noizu.MnesiaVersioning.Test.Migrate.run([])
    Amnesia.start
    assert Amnesia.Table.exists?(Noizu.MnesiaVersioning.SecondTestDatabase.SecondTestTable) == true
    assert Amnesia.Table.exists?(Noizu.MnesiaVersioning.TestDatabase.TestRecoveryTable) == true
    Noizu.MnesiaVersioning.TestDatabase.TestTable.wait()
    existing = Amnesia.Fragment.transaction do
      Noizu.MnesiaVersioning.TestDatabase.TestTable.read(1)
    end
    assert existing.value == "Goodbye World"
  end

  test "Rollback" do
    Noizu.MnesiaVersioning.Test.Install.run([])
    Noizu.MnesiaVersioning.Test.Migrate.run([])
    Amnesia.start
    assert Amnesia.Table.exists?(Noizu.MnesiaVersioning.SecondTestDatabase.SecondTestTable) == true
    assert Amnesia.Table.exists?(Noizu.MnesiaVersioning.TestDatabase.TestRecoveryTable) == true
    Noizu.MnesiaVersioning.TestDatabase.TestTable.wait()
    existing = Amnesia.Fragment.transaction do
      Noizu.MnesiaVersioning.TestDatabase.TestTable.read(1)
    end
    assert existing.value == "Goodbye World"
    Noizu.MnesiaVersioning.Test.Migrate.run(["rollback", "count", "1"])
    Amnesia.start
    assert Amnesia.Table.exists?(Noizu.MnesiaVersioning.SecondTestDatabase.SecondTestTable) == true
    assert Amnesia.Table.exists?(Noizu.MnesiaVersioning.TestDatabase.TestRecoveryTable) == false
    Noizu.MnesiaVersioning.TestDatabase.TestTable.wait()
    existing = Amnesia.Fragment.transaction do
      Noizu.MnesiaVersioning.TestDatabase.TestTable.read(1)
    end
    assert existing.value == "Hello World"
  end

  @tag :temp
  test "MigrateRollbackByCount" do
    Noizu.MnesiaVersioning.Test.Install.run([])
    Noizu.MnesiaVersioning.Test.Migrate.run(["count", "1"])
    Amnesia.start
    assert Amnesia.Table.exists?(Noizu.MnesiaVersioning.SecondTestDatabase.SecondTestTable) == true
    assert Amnesia.Table.exists?(Noizu.MnesiaVersioning.TestDatabase.TestRecoveryTable) == false

    Noizu.MnesiaVersioning.Test.Migrate.run(["rollback", "count", "1"])
    Amnesia.start
    assert Amnesia.Table.exists?(Noizu.MnesiaVersioning.SecondTestDatabase.SecondTestTable) == false
  end

  test "MigrateRollbackByChangeSet" do
    Noizu.MnesiaVersioning.Test.Install.run([])
    Noizu.MnesiaVersioning.Test.Migrate.run(["change", "TestCreate", "noizu"])
    Amnesia.start
    assert Amnesia.Table.exists?(Noizu.MnesiaVersioning.SecondTestDatabase.SecondTestTable) == true
    Noizu.MnesiaVersioning.Test.Migrate.run(["rollback", "change", "TestCreate", "noizu"])
    Amnesia.start
    assert Amnesia.Table.exists?(Noizu.MnesiaVersioning.SecondTestDatabase.SecondTestTable) == false
  end

end
