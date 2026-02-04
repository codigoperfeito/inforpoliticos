class Senator {
  Senator({
    required this.id,
    required this.displayName,
    required this.party,
    required this.uf,
    required this.photoUrl,
    this.fullName,
    this.email,
  });

  final int id;
  final String displayName;
  final String party;
  final String uf;
  final String photoUrl;
  final String? fullName;
  final String? email;

  static Senator fromJson(Map<String, dynamic> json) {
    final ident = _readIdent(json);
    final mandato = _readMandato(json);
    final rawId =
        ident['CodigoParlamentar'] ?? ident['codigoParlamentar'] ?? 0;
    return Senator(
      id: _toInt(rawId),
      displayName: _string(ident['NomeParlamentar']) ??
          _string(ident['nomeParlamentar']) ??
          _string(json['nome']) ??
          '',
      party: _string(ident['SiglaPartidoParlamentar']) ??
          _string(ident['siglaPartidoParlamentar']) ??
          _string(mandato['SiglaPartidoParlamentar']) ??
          _string(mandato['siglaPartidoParlamentar']) ??
          _string(json['siglaPartido']) ??
          '',
      uf: _string(ident['UfParlamentar']) ??
          _string(ident['ufParlamentar']) ??
          _string(mandato['UfParlamentar']) ??
          _string(mandato['ufParlamentar']) ??
          _string(json['uf']) ??
          '',
      photoUrl: _string(ident['UrlFotoParlamentar']) ??
          _string(ident['urlFotoParlamentar']) ??
          _string(json['urlFoto']) ??
          '',
      fullName: _string(ident['NomeCompletoParlamentar']) ??
          _string(ident['nomeCompletoParlamentar']) ??
          '',
      email: _string(ident['EmailParlamentar']) ??
          _string(ident['emailParlamentar']) ??
          _string(json['email']) ??
          '',
    );
  }

  static Senator fromCodanteJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? 0;
    return Senator(
      id: _toInt(rawId),
      displayName: _string(json['name']) ?? '',
      party: _string(json['party']) ?? '',
      uf: _string(json['UF']) ?? _string(json['uf']) ?? '',
      photoUrl: _string(json['avatar_url']) ?? '',
      fullName: _string(json['full_name']),
      email: _string(json['email']),
    );
  }

  static Senator fromDetailJson(Map<String, dynamic> json) {
    final root = json['DetalheParlamentar'] ??
        json['detalheParlamentar'] ??
        json;
    final parlamentar = (root is Map<String, dynamic>)
        ? (root['Parlamentar'] ?? root['parlamentar'] ?? root)
        : json;
    if (parlamentar is Map<String, dynamic>) {
      return Senator.fromJson(parlamentar);
    }
    return Senator.fromJson(json);
  }

  static Senator fromCacheJson(Map<String, dynamic> json) {
    return Senator(
      id: json['id'] as int? ?? 0,
      displayName: (json['displayName'] ?? '') as String,
      party: (json['party'] ?? '') as String,
      uf: (json['uf'] ?? '') as String,
      photoUrl: (json['photoUrl'] ?? '') as String,
      fullName: json['fullName'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'party': party,
      'uf': uf,
      'photoUrl': photoUrl,
      'fullName': fullName,
      'email': email,
    };
  }

  static String? _string(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.trim();
    return value.toString().trim();
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static Map<String, dynamic> _readIdent(Map<String, dynamic> json) {
    final direct = json['IdentificacaoParlamentar'] as Map<String, dynamic>? ??
        json['identificacaoParlamentar'] as Map<String, dynamic>?;
    if (direct != null) {
      return direct;
    }
    final root = json['Parlamentar'] ??
        json['parlamentar'] ??
        json['DetalheParlamentar'] ??
        json['detalheParlamentar'];
    if (root is Map<String, dynamic>) {
      final nested = root['IdentificacaoParlamentar'] ??
          root['identificacaoParlamentar'];
      if (nested is Map<String, dynamic>) {
        return nested;
      }
    }
    return {};
  }

  static Map<String, dynamic> _readMandato(Map<String, dynamic> json) {
    final direct = json['Mandato'] as Map<String, dynamic>? ??
        json['mandato'] as Map<String, dynamic>?;
    if (direct != null) {
      return direct;
    }
    final root = json['Parlamentar'] ??
        json['parlamentar'] ??
        json['DetalheParlamentar'] ??
        json['detalheParlamentar'];
    if (root is Map<String, dynamic>) {
      final nested = root['Mandato'] ?? root['mandato'];
      if (nested is Map<String, dynamic>) {
        return nested;
      }
    }
    return {};
  }
}
