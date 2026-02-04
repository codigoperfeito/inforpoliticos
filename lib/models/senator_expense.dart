class SenatorExpense {
  SenatorExpense({
    required this.description,
    required this.supplier,
    required this.cnpjCpf,
    required this.date,
    required this.amount,
    required this.raw,
  });

  final String description;
  final String supplier;
  final String cnpjCpf;
  final String date;
  final num? amount;
  final Map<String, dynamic> raw;

  factory SenatorExpense.fromJson(Map<String, dynamic> json) {
    final description = _firstString(json, [
      'descricao',
      'descricaoDespesa',
      'tipoDespesa',
      'detalhe',
      'descricaoDocumento',
    ]);
    final supplier = _firstString(json, [
      'fornecedor',
      'nomeFornecedor',
      'beneficiario',
      'credor',
    ]);
    final cnpjCpf = _firstString(json, [
      'cnpjCpf',
      'cpfCnpj',
      'cnpj',
      'cpf',
    ]);
    final date = _firstString(json, [
      'data',
      'dataDocumento',
      'dataDespesa',
      'dataEmissao',
    ]);
    final amount = _firstNum(json, [
      'valor',
      'valorReembolsado',
      'valoresReembolsado',
      'valorDespesa',
      'valorDocumento',
      'valorLiquido',
      'valorPago',
    ]);
    return SenatorExpense(
      description: description,
      supplier: supplier,
      cnpjCpf: cnpjCpf,
      date: date,
      amount: amount,
      raw: json,
    );
  }

  static String _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  static num? _firstNum(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value;
      if (value is String) {
        final parsed = num.tryParse(value.replaceAll(',', '.'));
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}
