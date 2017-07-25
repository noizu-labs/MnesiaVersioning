
defprotocol Noizu.MnesiaVersioning.ChangeProtocol do
  @fallback_to_any true
  def apply(self)
  def rollback(self)
  def auto_rollback?(self)
end
