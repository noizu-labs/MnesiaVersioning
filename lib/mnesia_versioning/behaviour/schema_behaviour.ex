#-------------------------------------------------------------------------------
# Author: Keith Brings <keith.brings@noizu.com>
# Copyright (C) 2017 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

defmodule Noizu.MnesiaVersioning.SchemaBehaviour do
  @moduledoc """
  This method provides information about the changesets we will be running.
  Currently only the change_sets() method is provided which should return a list of
  changesets structures to execute. In the future we will provide support for directory scanning,
  Similiar to how the test folders works.
  """

  @doc """
  Return array of changesets to be applied/rolledback.
  @note the current logic is fairly crude.
  One may simply implement a module that returns an inline array of changesets.

  ```
  defmodule MyApp.SchemaVersioning do
    @behaviour Noizu.MnesiaVersioning.SchemaBehaviour
    def change_sets() do
    [
      %ChangeSet{...},
      %ChangeSet{...},
    ]
    end
  end
  ```
  If desired, however, one could ofcourse put changesets into seperate module files
  and simply concatenate them together here.
  defmodule MyApp.SchemaVersioning do
    @behaviour Noizu.MnesiaVersioning.SchemaBehaviour
    def change_sets() do
      # where the following each return an array of change sets.
      MyApp.SchemaVersioning.UserFeature.change_sets() ++ MyApp.SchemaVersioning.PokerGameFeature.change_sets()
    end
  end
  """
  @callback change_sets() :: [Noizu.MnesiaVersioning.ChangeSet]

  #-----------------------------------------------------------------------------
  # Using Implementation
  #-----------------------------------------------------------------------------
  defmacro __using__(options) do
    default_timeout = options[:default_timeout] || 60_000
    default_cluster = options[:default_cluster] || :auto

    quote do
      import unquote(__MODULE__)
      @behaviour Noizu.MnesiaVersioning.SchemaBehaviour

      @default_timeout(unquote(default_timeout))
      @default_cluster(unquote(default_cluster))
      use Amnesia

      def create_table(tab, dist \\ :auto) do
        dist = case dist do
          :auto ->
            case @default_cluster do
              :auto -> [disk: [node()]]
              v -> v
            end
          v -> v
        end

        if !Amnesia.Table.exists?(tab) do
          :ok = tab.create(dist)
        end
      end

      def destroy_table(tab, timeout \\ @default_timeout) do
        if Amnesia.Table.exists?(tab) do
          :ok = Amnesia.Table.wait([tab], timeout)
          :ok = Amnesia.Table.destroy(tab)
        end
      end

    end # end __using__
  end # end macro

end
