#-------------------------------------------------------------------------------
# Author: Keith Brings <keith.brings@noizu.com>
# Copyright (C) 2017 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

defmodule Noizu.MnesiaVersioning.TopologyBehaviour do
  @callback mnesia_nodes() :: {:ok, [pid]} | {:error, any}
  @callback database() :: Module
end
