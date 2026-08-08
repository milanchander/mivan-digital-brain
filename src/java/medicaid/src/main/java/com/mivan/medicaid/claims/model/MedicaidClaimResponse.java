package com.mivan.medicaid.claims.model;

import lombok.Builder;
import lombok.Data;
import java.math.BigDecimal;

/** REST response DTO from the Medicaid claim processing pipeline. */
@Data
@Builder
public class MedicaidClaimResponse {
    private String claimId;
    private String memberId;
    private boolean eligible;
    private boolean tplFound;
    private BigDecimal tplPaidAmt;
    private BigDecimal medicaidLiabilityAmt;
    private String encounterStatus;
    private boolean stagedForSubmission;
    private String errorCode;
    private String errorMessage;

    public boolean isSuccess() {
        return stagedForSubmission && errorCode == null;
    }
}
