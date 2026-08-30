extension ListExtension<E> on List<E> {
  /// 返回第一个满足 [test] 的元素；未找到时返回 null。
  E? find(bool Function(E item) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}
