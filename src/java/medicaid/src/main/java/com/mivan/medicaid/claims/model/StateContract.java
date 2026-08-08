package com.mivan.medicaid.claims.model;

import jakarta.persistence.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;

/** Maps to DB2 STATE_CONTRACT — MCO state contract terms used by MMCOLRP0 and MMCOENC0. */
@Data
@Entity
@Table(name = "STATE_CONTRACT")
public class StateContract {

    @EmbeddedId
    private StateContractId id;

    @Column(name = "CONTRACT_ID", length = 15)
    private String contractId;

    @Column(name = "CAPITATION_RATE", precision = 9, scale = 2)
    private BigDecimal capitationRate;

    @Column(name = "TIMELY_FILING_DAYS")
    private Integer timelyFilingDays;

    @Column(name = "ENCOUNTER_DUE_DAYS")
    private Integer encounterDueDays;

    @Column(name = "EFFECTIVE_DT")
    private LocalDate effectiveDt;

    @Column(name = "TERM_DT")
    private LocalDate termDt;

    @Embeddable
    @Data
    public static class StateContractId implements java.io.Serializable {
        @Column(name = "STATE_CD", length = 2, nullable = false)
        private String stateCd;

        @Column(name = "MCO_ID", length = 10, nullable = false)
        private String mcoId;
    }
}
