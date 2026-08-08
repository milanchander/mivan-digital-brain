package com.mivan.ma.model;

import jakarta.persistence.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;

/** Maps to DB2 MA_ELIGIBILITY — COBOL copybook MAENROLL. */
@Data
@Entity
@Table(name = "MA_ELIGIBILITY")
public class MaEnrollment {

    @Id
    @Column(name = "MBI", length = 11, nullable = false)
    private String mbi;

    @Column(name = "HICN", length = 12)
    private String hicn;

    @Column(name = "CONTRACT_ID", length = 5, nullable = false)
    private String contractId;

    @Column(name = "PLAN_ID", length = 3, nullable = false)
    private String planId;

    @Column(name = "SEGMENT_ID", length = 3)
    private String segmentId;

    @Column(name = "MEMBER_LAST_NAME", length = 25)
    private String memberLastName;

    @Column(name = "MEMBER_FIRST_NAME", length = 20)
    private String memberFirstName;

    @Column(name = "DOB")
    private LocalDate dob;

    @Column(name = "GENDER", length = 1)
    private String gender;

    @Column(name = "EFF_DATE", nullable = false)
    private LocalDate effDate;

    @Column(name = "TERM_DATE")
    private LocalDate termDate;

    @Column(name = "LIS_LEVEL", length = 2)
    private String lisLevel;

    @Column(name = "DUAL_STATUS", length = 2)
    private String dualStatus;

    @Column(name = "ESRD_IND", length = 1)
    private String esrdInd;

    @Column(name = "RISK_SCORE", precision = 8, scale = 4)
    private BigDecimal riskScore;

    @Column(name = "COUNTY_CODE", length = 5)
    private String countyCode;

    @Column(name = "STATE_CODE", length = 2)
    private String stateCode;

    @Column(name = "STATUS_CD", length = 2, nullable = false)
    private String statusCd;
}
