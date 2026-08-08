package com.mivan.ma.model;

import jakarta.persistence.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;

/** Maps to DB2 MA_ENCOUNTER_STAGING — COBOL copybook MAENCSTG. */
@Data
@Entity
@Table(name = "MA_ENCOUNTER_STAGING")
public class MaEncounterStaging {

    @Id
    @Column(name = "ENCOUNTER_ID", length = 20, nullable = false)
    private String encounterId;

    @Column(name = "TRANSACTION_TYPE", length = 2, nullable = false)
    private String transactionType;

    @Column(name = "SUBMISSION_TYPE", length = 2, nullable = false)
    private String submissionType;

    @Column(name = "MBI", length = 11, nullable = false)
    private String mbi;

    @Column(name = "HICN", length = 12)
    private String hicn;

    @Column(name = "CONTRACT_ID", length = 5, nullable = false)
    private String contractId;

    @Column(name = "PLAN_ID", length = 3, nullable = false)
    private String planId;

    @Column(name = "BILLING_NPI", length = 10)
    private String billingNpi;

    @Column(name = "RENDERING_NPI", length = 10)
    private String renderingNpi;

    @Column(name = "FACILITY_NPI", length = 10)
    private String facilityNpi;

    @Column(name = "DOS_FROM", nullable = false)
    private LocalDate dosFrom;

    @Column(name = "DOS_THRU", nullable = false)
    private LocalDate dosThru;

    @Column(name = "TOTAL_BILLED", precision = 11, scale = 2)
    private BigDecimal totalBilled;

    @Column(name = "TOTAL_PAID", precision = 11, scale = 2)
    private BigDecimal totalPaid;

    @Column(name = "SUBMISSION_STATUS", length = 2, nullable = false)
    private String submissionStatus;

    @Column(name = "CMS_ICN", length = 23)
    private String cmsIcn;

    @Column(name = "SUBMIT_DATE")
    private LocalDate submitDate;

    @Column(name = "RESPONSE_DATE")
    private LocalDate responseDate;

    @Column(name = "ERROR_CODE", length = 4)
    private String errorCode;
}
