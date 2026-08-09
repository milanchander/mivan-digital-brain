package com.mivan.provider.validation.repository;

import com.mivan.provider.validation.model.OigExclusionList;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

/**
 * Repository for {@link OigExclusionList}.
 *
 * <p>Java equivalent of {@code MPRVEXC0} paragraph {@code 3000-CHECK-OIG-LEIE}.
 * An active (non-reinstated) match on either NPI or Tax ID is an exclusion
 * hit that prohibits payment.</p>
 */
@Repository
public interface OigExclusionRepository
        extends JpaRepository<OigExclusionList, Long> {

    /**
     * Active exclusions matching NPI or Tax ID.
     *
     * <p>Explicit JPQL is used so the OR/AND precedence is
     * {@code (npi = ? OR taxId = ?) AND reinstateDt IS NULL} rather than the
     * default derived-query grouping.</p>
     */
    @Query("SELECT o FROM OigExclusionList o "
         + "WHERE (o.npi = :npi OR o.taxId = :taxId) "
         + "AND o.reinstateDt IS NULL")
    List<OigExclusionList> findByNpiOrTaxIdAndReinstatedDtIsNull(
            @Param("npi") String npi, @Param("taxId") String taxId);
}
