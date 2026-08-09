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
 * State Medicaid exclusion entity.
 *
 * <p>Maps the DB2 {@code STATE_EXCLUSION_LIST} table. COBOL equivalent:
 * the state source screened by {@code MPRVEXC0} paragraph
 * {@code 3200-CHECK-STATE-EXCLUSION}.</p>
 */
@Entity
@Table(name = "state_exclusion_list")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StateExclusionList {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "excl_id")
    private Long exclId;

    @Column(name = "npi", length = 10)
    private String npi;

    @Column(name = "tax_id", length = 9)
    private String taxId;

    @Column(name = "state", length = 2)
    private String state;

    @Column(name = "excl_type_cd", length = 4)
    private String exclTypeCd;

    @Column(name = "effective_dt")
    private LocalDate effectiveDt;

    @Column(name = "reinstate_dt")
    private LocalDate reinstateDt;

    @Column(name = "reason_cd", length = 4)
    private String reasonCd;
}
