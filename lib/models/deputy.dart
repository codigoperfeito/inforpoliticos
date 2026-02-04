class Deputy {
  Deputy({
    required this.id,
    required this.displayName,
    required this.party,
    required this.uf,
    required this.photoUrl,
    this.fullName,
    this.email,
    this.phone,
    this.situation,
    this.electoralCondition,
    this.officeName,
    this.officeBuilding,
    this.officeFloor,
    this.officeRoom,
    this.birthDate,
    this.birthCity,
    this.birthUf,
    this.education,
    this.website,
    this.socialLinks = const [],
    this.gender,
  });

  final int id;
  final String displayName;
  final String party;
  final String uf;
  final String photoUrl;

  final String? fullName;
  final String? email;
  final String? phone;
  final String? situation;
  final String? electoralCondition;
  final String? officeName;
  final String? officeBuilding;
  final String? officeFloor;
  final String? officeRoom;
  final String? birthDate;
  final String? birthCity;
  final String? birthUf;
  final String? education;
  final String? website;
  final List<String> socialLinks;
  final String? gender;

  bool get isCurrent {
    final normalized = (situation ?? '').toLowerCase();
    if (normalized.contains('exerc')) {
      return true;
    }
    final election = (electoralCondition ?? '').toLowerCase();
    return election.contains('eleit');
  }

  static Deputy fromListJson(Map<String, dynamic> json) {
    return Deputy(
      id: json['id'] as int,
      displayName: (json['nome'] ?? '') as String,
      party: (json['siglaPartido'] ?? '') as String,
      uf: (json['siglaUf'] ?? '') as String,
      photoUrl: (json['urlFoto'] ?? '') as String,
      email: (json['email'] ?? '') as String,
    );
  }

  static Deputy fromDetailJson(Map<String, dynamic> json) {
    final ultimoStatus = json['ultimoStatus'] as Map<String, dynamic>? ?? {};
    final gabinete = ultimoStatus['gabinete'] as Map<String, dynamic>? ?? {};
    final redes = (json['redeSocial'] as List<dynamic>? ?? [])
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    return Deputy(
      id: json['id'] as int,
      displayName: (ultimoStatus['nome'] ?? json['nome'] ?? '') as String,
      party: (ultimoStatus['siglaPartido'] ?? '') as String,
      uf: (ultimoStatus['siglaUf'] ?? '') as String,
      photoUrl: (ultimoStatus['urlFoto'] ?? '') as String,
      fullName: (json['nomeCivil'] ?? '') as String,
      email: (ultimoStatus['email'] ?? '') as String,
      phone: (gabinete['telefone'] ?? '') as String,
      situation: (ultimoStatus['situacao'] ?? '') as String,
      electoralCondition: (ultimoStatus['condicaoEleitoral'] ?? '') as String,
      officeName: (gabinete['nome'] ?? '') as String,
      officeBuilding: (gabinete['predio'] ?? '') as String,
      officeFloor: (gabinete['andar'] ?? '') as String,
      officeRoom: (gabinete['sala'] ?? '') as String,
      birthDate: (json['dataNascimento'] ?? '') as String,
      birthCity: (json['municipioNascimento'] ?? '') as String,
      birthUf: (json['ufNascimento'] ?? '') as String,
      education: (json['escolaridade'] ?? '') as String,
      website: (json['urlWebsite'] ?? '') as String,
      socialLinks: redes,
      gender: (json['sexo'] ?? '') as String,
    );
  }

  static Deputy fromCacheJson(Map<String, dynamic> json) {
    return Deputy(
      id: json['id'] as int,
      displayName: (json['displayName'] ?? '') as String,
      party: (json['party'] ?? '') as String,
      uf: (json['uf'] ?? '') as String,
      photoUrl: (json['photoUrl'] ?? '') as String,
      fullName: json['fullName'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      situation: json['situation'] as String?,
      electoralCondition: json['electoralCondition'] as String?,
      officeName: json['officeName'] as String?,
      officeBuilding: json['officeBuilding'] as String?,
      officeFloor: json['officeFloor'] as String?,
      officeRoom: json['officeRoom'] as String?,
      birthDate: json['birthDate'] as String?,
      birthCity: json['birthCity'] as String?,
      birthUf: json['birthUf'] as String?,
      education: json['education'] as String?,
      website: json['website'] as String?,
      socialLinks: (json['socialLinks'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      gender: json['gender'] as String?,
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
      'phone': phone,
      'situation': situation,
      'electoralCondition': electoralCondition,
      'officeName': officeName,
      'officeBuilding': officeBuilding,
      'officeFloor': officeFloor,
      'officeRoom': officeRoom,
      'birthDate': birthDate,
      'birthCity': birthCity,
      'birthUf': birthUf,
      'education': education,
      'website': website,
      'socialLinks': socialLinks,
      'gender': gender,
    };
  }

  Deputy copyWithEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return this;
    }
    return Deputy(
      id: id,
      displayName: displayName,
      party: party,
      uf: uf,
      photoUrl: photoUrl,
      fullName: fullName,
      email: value,
      phone: phone,
      situation: situation,
      electoralCondition: electoralCondition,
      officeName: officeName,
      officeBuilding: officeBuilding,
      officeFloor: officeFloor,
      officeRoom: officeRoom,
      birthDate: birthDate,
      birthCity: birthCity,
      birthUf: birthUf,
      education: education,
      website: website,
      socialLinks: socialLinks,
      gender: gender,
    );
  }
}
