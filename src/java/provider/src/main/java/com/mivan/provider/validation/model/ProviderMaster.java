package com.mivan.provider.validation.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDate;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Provider Master entity.
 *
 * <p>Maps the DB2 {@code PROVIDER_MASTER} table and the {@code PROV-MSTR} VSAM
 * KSDS. COBOL copybook equivalent: {@code MPRVMSTR} ({@code PROVIDER-MASTER-REC}).</p>
 */
@Entity
@Table(name = "provider_master")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ProviderMaster {

    /** {@code PRV-NPI} — National Provider Identifier (VSAM key). */
    @Id
    @Column(name = "npi", length = 10)
    private String npi;

    /** {@code PRV-NPI-TYPE} — 1 = individual, 2 = organization. */
    @Column(name = "npi_type", length = 1)
    private String npiType;

    /** {@code PRV-TAX-ID}. */
    @Column(name = "tax_id", length = 9)
    private String taxId;

    @Column(name = "last_name", length = 35)
    private String lastName;

    @Column(name = "first_name", length = 25)
    private String firstName;

    @Column(name = "org_name", length = 60)
    private String orgName;

    @Column(name = "taxonomy_1", length = 10)
    private String taxonomy1;

    @Column(name = "taxonomy_2", length = 10)
    private String taxonomy2;

    @Column(name = "specialty_cd", length = 4)
    private String specialtyCd;

    @Column(name = "network_status", length = 3)
    private String networkStatus;

    @Column(name = "contract_id", length = 15)
    private String contractId;

    @Column(name = "network_tier", length = 2)
    private String networkTier;

    @Column(name = "cred_status", length = 2)
    private String credStatus;

    @Column(name = "cred_exp_dt")
    private LocalDate credExpDt;

    /** {@code PRV-EXCL-FLAG} — local exclusion flag ('Y' / 'N'). */
    @Column(name = "excl_flag", length = 1)
    private String exclFlag;

    @Column(name = "excl_dt")
    private LocalDate exclDt;

    @Column(name = "effective_dt")
    private LocalDate effectiveDt;

    @Column(name = "term_dt")
    private LocalDate termDt;

    @Column(name = "status_cd", length = 2)
    private String statusCd;
}
