package com.mivan.ma.model;

import jakarta.persistence.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;

/** Maps to DB2 MA_HCC_CROSSWALK — COBOL copybook MAHCCREC. */
@Data
@Entity
@Table(name = "MA_HCC_RECORD")
public class MaHccRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "HICN", length = 12)
    private String hicn;

    @Column(name = "MBI", length = 11, nullable = false)
    private String mbi;

    @Column(name = "PAYMENT_YEAR", length = 4, nullable = false)
    private String paymentYear;

    @Column(name = "MODEL_YEAR", length = 4, nullable = false)
    private String modelYear;

    @Column(name = "HCC_CODE", length = 4, nullable = false)
    private String hccCode;

    @Column(name = "HCC_LABEL", length = 60)
    private String hccLabel;

    @Column(name = "ICD10_CODE", length = 7, nullable = false)
    private String icd10Code;

    @Column(name = "ICD10_DESC", length = 80)
    private String icd10Desc;

    @Column(name = "DOS_FROM", nullable = false)
    private LocalDate dosFrom;

    @Column(name = "DOS_THRU", nullable = false)
    private LocalDate dosThru;

    @Column(name = "PROVIDER_NPI", length = 10)
    private String providerNpi;

    @Column(name = "PROVIDER_SPECIALTY", length = 3)
    private String providerSpecialty;

    @Column(name = "ENCOUNTER_ID", length = 20)
    private String encounterId;

    @Column(name = "CLAIM_TYPE", length = 2)
    private String claimType;

    @Column(name = "HIERARCHY_IND", length = 1)
    private String hierarchyInd;

    @Column(name = "HIERARCHICAL_HCC", length = 4)
    private String hierarchicalHcc;

    @Column(name = "RAF_COEFFICIENT", precision = 8, scale = 6)
    private BigDecimal rafCoefficient;

    @Column(name = "VALIDATION_STATUS", length = 2)
    private String validationStatus;

    @Column(name = "REJECT_REASON", length = 4)
    private String rejectReason;
}
