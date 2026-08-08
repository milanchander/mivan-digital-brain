package com.mivan.medicaid.claims.model;

import lombok.Data;
import java.time.LocalDate;

/** REST request DTO for triggering Medicaid claim processing. */
@Data
public class MedicaidClaimRequest {
    private String claimId;
    private String memberId;
    private String stateCd;
    private LocalDate dos;
}
