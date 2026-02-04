import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/deputy_extras.dart';

class LocalExtrasStore {
  const LocalExtrasStore();

  Future<DeputyExtras> loadExtras(int deputyId) async {
    final raw = await rootBundle.loadString('assets/data/extras.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final key = deputyId.toString();
    final data = (json[key] as Map<String, dynamic>?) ??
        (json['default'] as Map<String, dynamic>? ?? {});
    return DeputyExtras.fromJson(data);
  }
}
