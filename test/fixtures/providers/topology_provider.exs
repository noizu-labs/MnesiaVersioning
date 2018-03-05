#-------------------------------------------------------------------------------
# Author: Keith Brings
# Copyright (C) 2018 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

defmodule Noizu.MnesiaVersioning.Test.TopologyProvider do
  @behaviour Noizu.MnesiaVersioning.TopologyBehaviour

  def mnesia_nodes() do
    {:ok, [node()]}
  end

  def database() do
    [ Noizu.MnesiaVersioning.TestDatabase,  Noizu.MnesiaVersioning.SecondTestDatabase]
  end
end
