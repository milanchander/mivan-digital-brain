package com.mivan.ma.model;

import jakarta.persistence.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;

/** Maps to DB2 MA_RAF_SCORE — COBOL copybook MARAFSCR. */
@Data
@Entity
@Table(name = "MA_RAF_SCORE")
public class MaRafScore {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "MBI", length = 11, nullable = false)
    private String mbi;

    @Column(name = "HICN", length = 12)
    private String hicn;

    @Column(name = "CONTRACT_ID", length = 5, nullable = false)
    private String contractId;

    @Column(name = "PLAN_ID", length = 3, nullable = false)
    private String planId;

    @Column(name = "PAYMENT_YEAR", length = 4, nullable = false)
    private String paymentYear;

    @Column(name = "MODEL_TYPE", length = 3)
    private String modelType;

    @Column(name = "RISK_SEGMENT", length = 3)
    private String riskSegment;

    @Column(name = "DEMOGRAPHIC_SCORE", precision = 8, scale = 6)
    private BigDecimal demographicScore;

    @Column(name = "DISEASE_SCORE", precision = 8, scale = 6)
    private BigDecimal diseaseScore;

    @Column(name = "INTERACTION_SCORE", precision = 8, scale = 6)
    private BigDecimal interactionScore;

    @Column(name = "LIS_ADDER", precision = 8, scale = 6)
    private BigDecimal lisAdder;

    @Column(name = "DUAL_ADDER", precision = 8, scale = 6)
    private BigDecimal dualAdder;

    @Column(name = "TOTAL_RAF", precision = 8, scale = 6, nullable = false)
    private BigDecimal totalRaf;

    @Column(name = "PRIOR_RAF", precision = 8, scale = 6)
    private BigDecimal priorRaf;

    @Column(name = "RAF_DELTA", precision = 8, scale = 6)
    private BigDecimal rafDelta;

    @Column(name = "HCC_COUNT")
    private Integer hccCount;

    @Column(name = "NEW_ENROLLEE_IND", length = 1)
    private String newEnrolleeInd;

    @Column(name = "CALC_DATE")
    private LocalDate calcDate;

    @Column(name = "STATUS", length = 2)
    private String status;
}
