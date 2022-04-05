#-------------------------------------------------------------------------------
# Author: Keith Brings
# Copyright (C) 2018 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

use Amnesia
defdatabase Noizu.MnesiaVersioning.TestDatabase do
  @moduledoc """
  Simple database used for testing MnesiaVersioning libraries.
  """

  deftable TestTable, [:identifier, :value], type: :ordered_set, index: [] do
    @type t :: %TestTable{
      identifier: integer,
      value: String.t,
    }
  end # end deftable TestTable

  deftable TestRecoveryTable, [:identifier, :value], type: :ordered_set, index: [] do
    @type t :: %TestRecoveryTable{
      identifier: {:ref, Module, integer | atom},
      value: any,
    }
  end # end deftable TestRecoveryTable

end # end defdatabase SolaceBackend.MnesiaVersioning
