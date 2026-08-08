package com.mivan.medicaid.claims.model;

import jakarta.persistence.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;

/** Maps to DB2 MEDICAID_ELIGIBILITY — COBOL copybook MMCOELIG. */
@Data
@Entity
@Table(name = "MEDICAID_ELIGIBILITY")
public class MedicaidEligibility {

    @Id
    @Column(name = "MEMBER_ID", length = 15, nullable = false)
    private String memberId;

    @Column(name = "STATE_CD", length = 2, nullable = false)
    private String stateCd;

    @Column(name = "AID_CATEGORY", length = 4)
    private String aidCategory;

    @Column(name = "ELIG_FROM_DT", nullable = false)
    private LocalDate eligFromDt;

    @Column(name = "ELIG_TO_DT")
    private LocalDate eligToDt;

    @Column(name = "MCO_ID", length = 10)
    private String mcoId;

    @Column(name = "PLAN_TYPE", length = 4)
    private String planType;

    @Column(name = "DUAL_ELIG_IND", length = 1)
    private String dualEligInd;

    @Column(name = "SPEND_DOWN_IND", length = 1)
    private String spendDownInd;

    @Column(name = "SPEND_DOWN_AMT", precision = 9, scale = 2)
    private BigDecimal spendDownAmt;

    @Column(name = "CHIP_IND", length = 1)
    private String chipInd;

    @Column(name = "EPSDT_IND", length = 1)
    private String epsdtInd;

    @Column(name = "STATUS_CD", length = 2, nullable = false)
    private String statusCd;

    public boolean isActive() {
        return "AC".equals(statusCd);
    }

    public boolean isDualEligible() {
        return "Y".equals(dualEligInd);
    }

    public boolean hasSpendDown() {
        return "Y".equals(spendDownInd)
                && spendDownAmt != null
                && spendDownAmt.compareTo(BigDecimal.ZERO) > 0;
    }

    public boolean isEpsdt() {
        return "Y".equals(epsdtInd);
    }
}
