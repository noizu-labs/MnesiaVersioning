#-------------------------------------------------------------------------------
# Author: Keith Brings
# Copyright (C) 2018 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

use Amnesia

defdatabase Noizu.MnesiaVersioning.SecondTestDatabase do
  @moduledoc """
  Simple database used for testing MnesiaVersioning libraries.
  """

  deftable SecondTestTable, [:identifier, :value], type: :ordered_set, index: [] do
    @type t :: %SecondTestTable{
      identifier: integer,
      value: String.t,
    }
  end # end deftable TestTable

  deftable SecondTestRecoveryTable, [:identifier, :value], type: :ordered_set, index: [] do
    @type t :: %SecondTestRecoveryTable{
      identifier: {:ref, Module, integer | atom},
      value: any,
    }
  end # end deftable TestRecoveryTable

end # end defdatabase SolaceBackend.MnesiaVersioning
