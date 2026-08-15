enum CabTripCancellationReason {
  vehicleBreakdown('Vehicle breakdown'),
  operationalInstruction('Operational instruction'),
  safetyIssue('Safety issue'),
  routeInaccessible('Route inaccessible'),
  tripCreatedInError('Trip created in error'),
  other('Other');

  final String label;

  const CabTripCancellationReason(this.label);
}

class CabTripCancellation {
  final CabTripCancellationReason reason;
  final String explanation;

  const CabTripCancellation({required this.reason, this.explanation = ''});

  String get safeSummary {
    final detail = explanation.trim();
    return reason == CabTripCancellationReason.other && detail.isNotEmpty
        ? '${reason.label}: $detail'
        : reason.label;
  }

  void validate() {
    if (reason == CabTripCancellationReason.other &&
        explanation.trim().isEmpty) {
      throw StateError(
        'Explain the cancellation reason when Other is selected.',
      );
    }
  }
}
