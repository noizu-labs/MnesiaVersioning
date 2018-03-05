#-------------------------------------------------------------------------------
# Author: Keith Brings
# Copyright (C) 2018 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

defmodule Noizu.MnesiaVersioning.ChangeSet do
  @moduledoc """
  This structure contains the steps required to apply or rollback a schema change,
  along with meta data such as the given name of the change `changeset`, editor `:author`,
  and misc. notes on what is being changes `:note`
  """

  alias Noizu.MnesiaVersioning.ChangeSet
  @type t :: %ChangeSet{
    changeset: String.t,
    author: String.t,
    note: String.t | :nil,
    environments: [] | :all,
    update: [] | any,
    rollback: [] | :auto
  }

  defstruct [
    changeset: :nil,
    author: :nil,
    note: :nil,
    environments: :all,
    update: nil,
    rollback: :auto,
  ]
end
