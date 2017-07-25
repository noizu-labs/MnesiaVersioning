#-------------------------------------------------------------------------------
# Author: Keith Brings <keith.brings@noizu.com>
# Copyright (C) 2017 Noizu Labs, Inc. All rights reserved.
#-----------------------------------

defmodule Noizu.MnesiaVersioning.ChangeSet do
  alias Noizu.MnesiaVersioning.ChangeSet
  @type t :: %ChangeSet{
    changeset: String.t,
    author: String.t,
    note: String.t | :nil,
    update: [],
    rollback: [] | :auto
  }

  defstruct [
    changeset: :nil,
    author: :nil,
    note: :nil,
    update: [],
    rollback: :auto,
  ]
end
