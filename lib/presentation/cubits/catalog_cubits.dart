import 'package:financeiro_ai/domain/merchant_rule.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/repositories/repositories.dart';
import 'package:financeiro_ai/domain/review_item.dart';
import 'package:financeiro_ai/domain/shortcut_token.dart';
import 'package:financeiro_ai/presentation/cubits/list_cubit.dart';

/// Loaded when its screen opens rather than folded into the ledger, so the
/// first paint does not wait on data most sessions never look at.
class ReviewQueueCubit extends ListCubit<ReviewItem> {
  ReviewQueueCubit(this._repository);
  final ReviewRepository _repository;

  @override
  Future<List<ReviewItem>> fetch() => _repository.loadReviewQueue();

  Future<void> settle(String id, {required String status}) =>
      _repository.settleReview(id, status: status);
}

class MerchantRulesCubit extends ListCubit<MerchantRule> {
  MerchantRulesCubit(this._repository);
  final ReviewRepository _repository;

  @override
  Future<List<MerchantRule>> fetch() => _repository.loadMerchantRules();

  Future<void> save(MerchantRuleDraft draft) async {
    await _repository.saveMerchantRule(draft);
    await reload();
  }

  Future<void> remove(String id) async {
    await _repository.deleteMerchantRule(id);
    await reload();
  }
}

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

class ImportBatchesCubit extends ListCubit<ImportBatch> {
  ImportBatchesCubit(this._repository);
  final InvoiceRepository _repository;

  @override
  Future<List<ImportBatch>> fetch() => _repository.loadImportBatches();
}
