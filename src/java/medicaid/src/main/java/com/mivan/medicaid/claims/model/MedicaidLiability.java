package com.mivan.medicaid.claims.model;

import jakarta.persistence.*;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Maps to DB2 MEDICAID_LIABILITY — COBOL copybook MMCOLIAB.
 * Represents the final payer-of-last-resort calculation per 42 CFR 433.139.
 * medicaidAmt = billedAmt - tplPaidAmt - memberRespAmt (floor 0).
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "MEDICAID_LIABILITY")
public class MedicaidLiability {

    @Id
    @Column(name = "CLAIM_ID", length = 20, nullable = false)
    private String claimId;

    @Column(name = "MEMBER_ID", length = 15, nullable = false)
    private String memberId;

    @Column(name = "STATE_CD", length = 2, nullable = false)
    private String stateCd;

    @Column(name = "BILLED_AMT", precision = 9, scale = 2)
    private BigDecimal billedAmt;

    @Column(name = "TPL_PAID_AMT", precision = 9, scale = 2)
    private BigDecimal tplPaidAmt;

    @Column(name = "MEMBER_RESP_AMT", precision = 9, scale = 2)
    private BigDecimal memberRespAmt;

    @Column(name = "MEDICAID_AMT", precision = 9, scale = 2)
    private BigDecimal medicaidAmt;

    @Column(name = "CALC_DT")
    private LocalDate calcDt;

    @Column(name = "STATUS_CD", length = 2)
    private String statusCd;

    public boolean isZeroLiability() {
        return medicaidAmt == null
                || medicaidAmt.compareTo(BigDecimal.ZERO) == 0;
    }
}
