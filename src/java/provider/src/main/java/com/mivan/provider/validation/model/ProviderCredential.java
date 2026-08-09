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
 * Provider Credential entity.
 *
 * <p>Maps the DB2 {@code PROVIDER_CREDENTIAL} table. COBOL copybook equivalent:
 * {@code MPRVCRED} ({@code PROVIDER-CRED-REC}). A provider may hold several
 * credential rows (license, DEA, malpractice, board certification).</p>
 */
@Entity
@Table(name = "provider_credential")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ProviderCredential {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "cred_id")
    private Long credId;

    @Column(name = "npi", length = 10)
    private String npi;

    /** {@code CRED-TYPE-CD} — LIC, DEA, MALP, BORD, etc. */
    @Column(name = "type_cd", length = 4)
    private String typeCd;

    @Column(name = "issuer", length = 40)
    private String issuer;

    @Column(name = "number", length = 20)
    private String number;

    @Column(name = "state", length = 2)
    private String state;

    @Column(name = "issue_dt")
    private LocalDate issueDt;

    @Column(name = "expiry_dt")
    private LocalDate expiryDt;

    @Column(name = "status_cd", length = 2)
    private String statusCd;

    @Column(name = "verified_dt")
    private LocalDate verifiedDt;

    @Column(name = "verified_by", length = 10)
    private String verifiedBy;

    @Column(name = "caqh_id", length = 10)
    private String caqhId;
}
