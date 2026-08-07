package com.mivan.micps.model;
import com.mivan.micps.service.DuplicateClaimDetectionService.EvaluationResult;

/**
 * Outbound DTO for POST /api/v1/claims/evaluate.
 * Wraps EvaluationResult with a human-readable message.
 */
public record DuplicateCheckResponse(
    String  claimId,
    String  outcome,
    String  matchType,
    String  originalClaimId,
    String  message
) {
    public static DuplicateCheckResponse from(EvaluationResult r) {
        String msg = switch (r.outcome()) {
            case NEAR_DUP -> "Claim pended: near-duplicate of " + r.originalClaimId() + " (" + r.matchType() + ")";
            case CLEAN    -> "Claim passed duplicate screening";
            case SKIPPED  -> "Claim excluded from screening (ED/override rule)";
        };
        return new DuplicateCheckResponse(
            r.claimId(),
            r.outcome().name(),
            r.matchType() != null ? r.matchType().name() : null,
            r.originalClaimId(),
            msg
        );
    }
}