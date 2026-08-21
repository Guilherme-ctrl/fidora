import 'package:financeiro_ai/features/ledger/domain/repositories/repositories.dart';
import 'package:financeiro_ai/features/ledger/presenter/cubits/list_cubit.dart';
import 'package:financeiro_ai/features/review/domain/merchant_rule.dart';
import 'package:financeiro_ai/features/review/domain/review_item.dart';

/// Moved out of `catalog`, where the mechanical modularisation had left it.
/// A file called `catalog_cubits.dart` holding the review queue, the shortcut
/// tokens and the import batches was five cross-feature edges that existed for
/// no reason but the name of the file they were in.

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
