class ExpenseItem {
  ExpenseItem({
    required this.type,
    required this.supplier,
    required this.description,
    required this.date,
    required this.value,
    this.documentUrl,
    this.documentNumber,
    this.year,
    this.month,
    this.cnpjCpf,
  });

  final String type;
  final String supplier;
  final String description;
  final String date;
  final double value;
  final String? documentUrl;
  final String? documentNumber;
  final int? year;
  final int? month;
  final String? cnpjCpf;

  static ExpenseItem fromJson(Map<String, dynamic> json) {
    return ExpenseItem(
      type: (json['tipoDespesa'] ?? '') as String,
      supplier: (json['nomeFornecedor'] ?? '') as String,
      description: (json['descricao'] ??
              json['especificacao'] ??
              '') as String,
      date: (json['dataDocumento'] ?? '') as String,
      value: (json['valorLiquido'] as num?)?.toDouble() ?? 0,
      documentUrl: json['urlDocumento'] as String?,
      documentNumber: (json['numDocumento'] ?? '') as String,
      year: (json['ano'] as num?)?.toInt(),
      month: (json['mes'] as num?)?.toInt(),
      cnpjCpf: (json['cnpjCpfFornecedor'] ?? '') as String,
    );
  }
}
