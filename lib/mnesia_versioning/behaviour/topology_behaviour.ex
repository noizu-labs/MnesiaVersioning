#-------------------------------------------------------------------------------
# Author: Keith Brings
# Copyright (C) 2018 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

defmodule Noizu.MnesiaVersioning.TopologyBehaviour do
  @moduledoc """
  The Topology behaviour allows a user to pass environment information to the versioning system such as mnesia nodes schema should be created on
  and the name of the database under version control.
  """

  @doc """
  The mnesia_nodes function should return the list of mnesia instances that tables are created on.
  Users may, ofcourse, use different nodes in their changeset.update/rollback steps however they must provide
  additional logic to insure nodes are reachable/linked.
  """
  @callback mnesia_nodes() :: {:ok, [pid]} | {:error, any}

  @doc """
  The method simply returns the name of the user's Amnesia Database(s) (defdatabase) modules under version control.
  After the migrate tasks has completed logic is run to insure all existing tables are online before halting Amnesia.
  To avoid ets insert and or synch problems during schema migration.

  ```
    tables = table.tables()
    for table <- tables do
      if(Amnesia.Table.exists?(table)) do
        Amnesia.Table.wait([table])
      end
    end
  ```

  """
  @callback database() :: Module | [Module]
end
