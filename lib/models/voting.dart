class Voting {
  Voting({
    required this.id,
    required this.dateTime,
    required this.summary,
    this.propositionId,
    this.ementa,
  });

  final String id;
  final String dateTime;
  final String summary;
  final int? propositionId;
  final String? ementa;

  static Voting fromJson(Map<String, dynamic> json) {
    return Voting(
      id: (json['id'] ?? '') as String,
      dateTime: (json['dataHoraRegistro'] ?? '') as String,
      summary: (json['descricao'] ?? '') as String,
      propositionId: (json['idProposicao'] as num?)?.toInt(),
      ementa: (json['ementa'] ?? '') as String,
    );
  }
}

class DeputyVote {
  DeputyVote({
    required this.deputyId,
    required this.vote,
    required this.name,
  });

  final int deputyId;
  final String vote;
  final String name;

  static DeputyVote fromJson(Map<String, dynamic> json) {
    return DeputyVote(
      deputyId: (json['idDeputado'] as num?)?.toInt() ?? 0,
      vote: (json['voto'] ?? '') as String,
      name: (json['nome'] ?? '') as String,
    );
  }
}
