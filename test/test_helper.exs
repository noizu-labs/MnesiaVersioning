#-------------------------------------------------------------------------------
# Author: Keith Brings
# Copyright (C) 2018 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

# Mnesia
#Code.require_file("test/fixtures/mnesia/test_database.exs")
#Code.require_file("test/fixtures/mnesia/second_test_database.exs")

# Providers
#Code.require_file("test/fixtures/providers/schema_provider.exs")
#Code.require_file("test/fixtures/providers/topology_provider.exs")

# Tasks
#Code.require_file("test/fixtures/tasks/install.exs")
#Code.require_file("test/fixtures/tasks/migrate.exs")

# http://elixir-lang.org/docs/stable/ex_unit/ExUnit.html#start/1
ExUnit.start(capture_log: true)

#Mix.Task.run "ecto.create", ~w(-r Ingressor.Repo --quiet)
#Mix.Task.run "ecto.migrate", ~w(-r Ingressor.Repo --quiet)
#Ecto.Adapters.SQL.begin_test_transaction(Ingressor.Repo)
