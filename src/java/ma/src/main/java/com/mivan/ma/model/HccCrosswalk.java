package com.mivan.ma.model;

import jakarta.persistence.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;

/** Maps to DB2 MA_HCC_CROSSWALK reference table — used by MAHCCVL0. */
@Data
@Entity
@Table(name = "MA_HCC_CROSSWALK")
public class HccCrosswalk {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "ICD10_CODE", length = 7, nullable = false)
    private String icd10Code;

    @Column(name = "HCC_CODE", length = 4, nullable = false)
    private String hccCode;

    @Column(name = "HCC_LABEL", length = 60, nullable = false)
    private String hccLabel;

    @Column(name = "RAF_COEFFICIENT", precision = 8, scale = 6, nullable = false)
    private BigDecimal rafCoefficient;

    @Column(name = "HIERARCHICAL_HCC", length = 4)
    private String hierarchicalHcc;

    @Column(name = "EFF_DATE", nullable = false)
    private LocalDate effDate;

    @Column(name = "TERM_DATE")
    private LocalDate termDate;

    @Column(name = "MODEL_YEAR", length = 4, nullable = false)
    private String modelYear;
}
