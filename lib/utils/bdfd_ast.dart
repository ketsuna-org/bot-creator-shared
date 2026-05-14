abstract class BdfdAstNode {
  const BdfdAstNode({this.start, this.end});

  final int? start;
  final int? end;
}

String normalizeBdfdFunctionName(String name) {
  final trimmed = name.trim();
  if (trimmed.startsWith(r'$')) {
    return trimmed.substring(1).toLowerCase();
  }
  return trimmed.toLowerCase();
}

class BdfdScriptAst {
  const BdfdScriptAst({required this.nodes});

  final List<BdfdAstNode> nodes;
}

class BdfdTextAst extends BdfdAstNode {
  const BdfdTextAst(this.value, {super.start, super.end});

  final String value;
}

class BdfdFunctionCallAst extends BdfdAstNode {
  const BdfdFunctionCallAst({
    required this.name,
    this.arguments = const <List<BdfdAstNode>>[],
    super.start,
    super.end,
  });

  final String name;
  final List<List<BdfdAstNode>> arguments;

  String get normalizedName => normalizeBdfdFunctionName(name);
}
