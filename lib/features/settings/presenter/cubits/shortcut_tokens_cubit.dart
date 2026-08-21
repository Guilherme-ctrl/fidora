import 'package:financeiro_ai/features/ledger/domain/repositories/repositories.dart';
import 'package:financeiro_ai/features/ledger/presenter/cubits/list_cubit.dart';
import 'package:financeiro_ai/features/settings/domain/shortcut_token.dart';

/// Moved out of `catalog`, where the mechanical modularisation had left it.
/// A file called `catalog_cubits.dart` holding the review queue, the shortcut
/// tokens and the import batches was five cross-feature edges that existed for
/// no reason but the name of the file they were in.

class ShortcutTokensCubit extends ListCubit<ShortcutToken> {
  ShortcutTokensCubit(this._repository);
  final ShortcutTokenRepository _repository;

  @override
  Future<List<ShortcutToken>> fetch() => _repository.loadShortcutTokens();

  /// Returns the issued token so the screen can show the secret once. It is
  /// deliberately not put into the state: a secret that lives in a state object
  /// survives every rebuild that reads it.
  Future<IssuedShortcutToken> issue(String name) async {
    final issued = await _repository.createShortcutToken(name);
    await reload();
    return issued;
  }

  Future<void> revoke(String id) async {
    await _repository.revokeShortcutToken(id);
    await reload();
  }
}
