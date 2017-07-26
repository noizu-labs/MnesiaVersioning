
defprotocol Noizu.MnesiaVersioning.ChangeProtocol do
  @moduledoc """
    This protocol will be used to provide changeset steps that can automatically generate rollback commands.
    The migration command will use this protocal to see if a given changeset's update command(s)
    can be automatically rollbacked if no rollback options are provided.

    This will allow, for example, the user to simply include  create table changesets and need to to explicitly include boilerplate
    `MyTable.wait()` and `MyTable.destroy()` calls in their rollback steps.

    @NOT_YET_IMPLEMENTED
  """
  @fallback_to_any true
  def apply(this)
  def rollback(this)
  def auto_rollback?(this)
end

defimpl Noizu.MnesiaVersioning.ChangeProtocol, for: Any do
  def apply(_this) do
    :nyi
  end

  def rollback(_this) do
    :nyi
  end

  def auto_rollback?(_this) do
    false
  end
end
