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
 * SAM (System for Award Management) exclusion entity.
 *
 * <p>Maps the DB2 {@code SAM_EXCLUSION_LIST} table. COBOL equivalent:
 * the SAM source screened by {@code MPRVEXC0} paragraph
 * {@code 3100-CHECK-SAM-EXCLUSION}.</p>
 */
@Entity
@Table(name = "sam_exclusion_list")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SamExclusionList {

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

    @Column(name = "reinstate_dt")
    private LocalDate reinstateDt;

    @Column(name = "reason_cd", length = 4)
    private String reasonCd;
}
