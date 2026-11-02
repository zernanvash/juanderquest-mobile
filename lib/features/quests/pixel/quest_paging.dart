int nextPageCount(int current, int total, {int step = 10}) {
  if (current >= total) return total;
  final next = current + step;
  return next > total ? total : next;
}
