/// Gera um nome de canal Realtime único.
///
/// Nomes fixos causaram erros de "cannot add postgres_changes callbacks after
/// subscribe()" quando o mesmo canal era reutilizado. Sempre use esta função.
String realtimeChannelName(String scope, [String? key]) {
  final suffix = DateTime.now().microsecondsSinceEpoch;
  return key == null ? '$scope-$suffix' : '$scope-$key-$suffix';
}
