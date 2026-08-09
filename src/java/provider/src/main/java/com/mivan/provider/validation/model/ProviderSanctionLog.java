package com.mivan.provider.validation.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Provider Sanction Log entity — the mandatory audit trail.
 *
 * <p>Maps the DB2 {@code PROVIDER_SANCTION_LOG} table. COBOL equivalent:
 * the record written by {@code MPRVSANL0}. One row is written for every
 * provider validation, whether the outcome is clean or an exclusion hit.</p>
 */
@Entity
@Table(name = "provider_sanction_log")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ProviderSanctionLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "log_id")
    private Long logId;

    @Column(name = "npi", length = 10)
    private String npi;

    /** {@code EVENT-CD} — VALD (validation) or EXCL (exclusion). */
    @Column(name = "event_cd", length = 4)
    private String eventCd;

    @Column(name = "valid_flag", length = 1)
    private String validFlag;

    @Column(name = "excl_flag", length = 1)
    private String exclFlag;

    @Column(name = "deny_reason", length = 30)
    private String denyReason;

    @Column(name = "network_ind", length = 3)
    private String networkInd;

    @Column(name = "tier_cd", length = 2)
    private String tierCd;

    @Column(name = "log_ts")
    private LocalDateTime logTs;
}
