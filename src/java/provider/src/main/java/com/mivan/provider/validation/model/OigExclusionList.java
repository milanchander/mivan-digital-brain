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
 * OIG LEIE (List of Excluded Individuals/Entities) entity.
 *
 * <p>Maps the DB2 {@code OIG_EXCLUSION_LIST} table. COBOL equivalent:
 * the OIG source screened by {@code MPRVEXC0} paragraph
 * {@code 3000-CHECK-OIG-LEIE}.</p>
 *
 * <p><strong>Compliance:</strong> an active (non-reinstated) row means federal
 * law prohibits payment to the provider.</p>
 */
@Entity
@Table(name = "oig_exclusion_list")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OigExclusionList {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "excl_id")
    private Long exclId;

    @Column(name = "npi", length = 10)
    private String npi;

    @Column(name = "tax_id", length = 9)
    private String taxId;

    @Column(name = "excl_type_cd", length = 4)
    private String exclTypeCd;

    @Column(name = "effective_dt")
    private LocalDate effectiveDt;

    /** Null while the exclusion is active; set when the provider is reinstated. */
    @Column(name = "reinstate_dt")
    private LocalDate reinstateDt;

    @Column(name = "reason_cd", length = 4)
    private String reasonCd;
}
