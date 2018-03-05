#-------------------------------------------------------------------------------
# Author: Keith Brings
# Copyright (C) 2018 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

defmodule Noizu.MnesiaVersioning.Test.Install do
  use Noizu.MnesiaVersioning.Tasks.Install,
    topology_provider: Noizu.MnesiaVersioning.Test.TopologyProvider,
    schema_provider: Noizu.MnesiaVersioning.Test.SchemaProvider,
    silent: true

end
