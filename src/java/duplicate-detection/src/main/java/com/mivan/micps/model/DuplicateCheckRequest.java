package com.mivan.micps.model;
import java.math.BigDecimal;

/**
 * Inbound DTO for POST /api/v1/claims/evaluate.
 * Decouples the REST API surface from the JPA entity.
 */
public record DuplicateCheckRequest(
    String  claimId,
    String  memberId,
    String  provNpi,
    Integer dosFrom,
    Integer dosTo,
    String  cptCd,
    String  modifier1,
    String  modifier2,
    BigDecimal chargeAmt,
    BigDecimal paidAmt,
    String  paymentStatusCd,
    Integer paymentDt
) {
    /** Convert to JPA entity for service layer. */
    public ClaimPayment toEntity() {
        return ClaimPayment.builder()
            .claimId(claimId).memberId(memberId).provNpi(provNpi)
            .dosFrom(dosFrom).dosTo(dosTo).cptCd(cptCd)
            .modifier1(modifier1).modifier2(modifier2)
            .chargeAmt(chargeAmt).paidAmt(paidAmt)
            .paymentStatusCd(paymentStatusCd).paymentDt(paymentDt)
            .build();
    }
}