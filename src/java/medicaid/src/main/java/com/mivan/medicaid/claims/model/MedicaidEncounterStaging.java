package com.mivan.medicaid.claims.model;

import jakarta.persistence.*;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDate;

/** Maps to DB2 MEDICAID_ENCOUNTER_STAGING — COBOL copybook MMCOENCR (ESDS VSAM). */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "MEDICAID_ENCOUNTER_STAGING")
public class MedicaidEncounterStaging {

    @Id
    @Column(name = "CLAIM_ID", length = 20, nullable = false)
    private String claimId;

    @Column(name = "MEMBER_ID", length = 15, nullable = false)
    private String memberId;

    @Column(name = "STATE_CD", length = 2, nullable = false)
    private String stateCd;

    @Column(name = "MCO_ID", length = 10)
    private String mcoId;

    @Column(name = "PROV_NPI", length = 10)
    private String provNpi;

    @Column(name = "DOS_FROM")
    private LocalDate dosFrom;

    @Column(name = "DOS_TO")
    private LocalDate dosTo;

    @Column(name = "DIAG_1", length = 7)
    private String diag1;

    @Column(name = "PROC_CD", length = 5)
    private String procCd;

    @Column(name = "BILLED_AMT", precision = 9, scale = 2)
    private BigDecimal billedAmt;

    @Column(name = "PAID_AMT", precision = 9, scale = 2)
    private BigDecimal paidAmt;

    @Column(name = "TPL_AMT", precision = 9, scale = 2)
    private BigDecimal tplAmt;

    @Column(name = "STATUS", length = 2)
    private String status;

    public boolean isReadyForSubmission() {
        return memberId != null && !memberId.isBlank()
                && provNpi != null && !provNpi.isBlank()
                && dosFrom != null;
    }
}
