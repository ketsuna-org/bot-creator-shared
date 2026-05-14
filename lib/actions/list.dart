// We will create a "new list" based on the current list provided. A special function will be used inside to format the current list

Map<String, dynamic> formatList(
  List<dynamic> list,
  String format, {
  int itemPerPage = 10,
  int page = 1,
}) {
  // Defensive: ensure sensible pagination parameters
  final safeItemPerPage = itemPerPage <= 0 ? 1 : itemPerPage;
  final safePage = page < 1 ? 1 : page;

  final startIndex = (safePage - 1) * safeItemPerPage;
  final endIndex = startIndex + safeItemPerPage;

  final paginatedList = (startIndex >= list.length)
      ? <dynamic>[]
      : list.sublist(
          startIndex,
          endIndex > list.length ? list.length : endIndex,
        );

  final computedList = paginatedList.map((item) {
    if (format.isEmpty) {
      return item.toString();
    }

    return format.replaceAll('{{item}}', item.toString());
  }).toList();

  return {
    'page': safePage.toString(),
    'totalPages': (list.length / safeItemPerPage).ceil().toString(),
    'computedList': computedList,
  };
}
