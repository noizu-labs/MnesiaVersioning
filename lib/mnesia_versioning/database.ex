#-------------------------------------------------------------------------------
# Author: Keith Brings <keith.brings@noizu.com>
# Copyright (C) 2017 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

use Amnesia
defdatabase Noizu.MnesiaVersioning.Database do
  @moduledoc """
  The Changeset table is responsbile for tracking database changset status.
  Schema changes are packaged into changesets that include apply and rollback methods.
  When using Noizu Provided helpers the system is capable of generating the appropriate rolback steps.
  """
  deftable ChangeSets, [:key, :changeset, :author, :note, :date, :state, :hash], type: :ordered_set, index: [:changeset, :author] do
    @type t :: %ChangeSets{
      key: {String.t, String.t},
      changeset: String.t,
      author: String.t,
      note: String.t,
      date: Timex.DateTime.t,
      state: :applied | :removed | :pending | :failure,
      hash: String.t
    }

    def from_change_set(changeset, outcome) do
      %Noizu.MnesiaVersioning.Database.ChangeSets{
        key: {changeset.changeset, changeset.author},
        changeset: changeset.changeset,
        author: changeset.author,
        note: changeset.note,
        date: Timex.now,
        state: outcome,
        hash: "HASH SUPPORT PENDING"
      }
    end # end from_change_set/2
  end # end deftable ChangeSets
end # end defdatabase SolaceBackend.MnesiaVersioning
