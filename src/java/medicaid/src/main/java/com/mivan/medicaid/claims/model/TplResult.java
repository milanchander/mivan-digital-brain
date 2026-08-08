package com.mivan.medicaid.claims.model;

import jakarta.persistence.*;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDate;

/** Maps to DB2 TPL_RESULT — COBOL copybook MMCOTPLR. 42 CFR 433.139. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "TPL_RESULT")
public class TplResult {

    @Id
    @Column(name = "CLAIM_ID", length = 20, nullable = false)
    private String claimId;

    @Column(name = "MEMBER_ID", length = 15, nullable = false)
    private String memberId;

    @Column(name = "PAYER_ID", length = 10)
    private String payerId;

    @Column(name = "PAYER_NAME", length = 40)
    private String payerName;

    @Column(name = "POLICY_NO", length = 20)
    private String policyNo;

    @Column(name = "PAID_AMT", precision = 9, scale = 2)
    private BigDecimal paidAmt;

    @Column(name = "PAID_DT")
    private LocalDate paidDt;

    @Column(name = "LAST_RESORT_AMT", precision = 9, scale = 2)
    private BigDecimal lastResortAmt;

    @Column(name = "STATUS_CD", length = 2)
    private String statusCd;

    public boolean hasTpl() {
        return paidAmt != null && paidAmt.compareTo(BigDecimal.ZERO) > 0;
    }
}
