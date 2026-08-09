package com.mivan.provider.validation.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDate;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Network Contract entity.
 *
 * <p>Maps the DB2 {@code NETWORK_CONTRACT} table. COBOL copybook equivalent:
 * {@code MPRVNETW} ({@code NETWORK-CONTRACT-REC}), consumed by {@code MPRVNET0}.</p>
 */
@Entity
@Table(name = "network_contract")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NetworkContract {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "contract_pk")
    private Long contractPk;

    @Column(name = "npi", length = 10)
    private String npi;

    @Column(name = "contract_id", length = 15)
    private String contractId;

    @Column(name = "network_id", length = 10)
    private String networkId;

    @Column(name = "tier_cd", length = 2)
    private String tierCd;

    @Column(name = "fee_sched_id", length = 10)
    private String feeSchedId;

    @Column(name = "effective_dt")
    private LocalDate effectiveDt;

    @Column(name = "term_dt")
    private LocalDate termDt;

    @Column(name = "status_cd", length = 2)
    private String statusCd;

    @Column(name = "accept_new_pat", length = 1)
    private String acceptNewPat;
}
