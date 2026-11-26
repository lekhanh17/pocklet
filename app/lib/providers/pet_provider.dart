import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pet.dart';

/// Pet nguoi dung da chon, luu tren may (khong can API).
/// Null la chua chon -> man Hom nay hien man chon pet.
class PetKindNotifier extends AsyncNotifier<PetKind?> {
  static const _key = 'pet_kind';

  @override
  Future<PetKind?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_key);
    for (final kind in PetKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }

  Future<void> choose(PetKind kind) async {
    state = AsyncData(kind);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, kind.name);
  }
}

final petKindProvider =
    AsyncNotifierProvider<PetKindNotifier, PetKind?>(PetKindNotifier.new);