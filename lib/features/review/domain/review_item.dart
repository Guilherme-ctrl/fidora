/// An entry in the review queue. `transaction_id` is nullable because the
/// spreadsheet migration stages reviews whose transaction was never matched.
class ReviewItem {
  const ReviewItem({
    required this.id,
    required this.reason,
    required this.status,
    this.transactionId,
    this.itemType,
    this.description,
    this.suggestedAction,
    this.createdAt,
  });

  final String id;
  final String reason;
  final String status;
  final String? transactionId;
  final String? itemType;
  final String? description;
  final String? suggestedAction;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
  bool get hasTransaction => transactionId != null;

  /// What the row is about, falling back through the columns the two import
  /// paths populate differently.
  String get title => switch (description) {
    final value? when value.trim().isNotEmpty => value,
    _ => reason,
  };
}
