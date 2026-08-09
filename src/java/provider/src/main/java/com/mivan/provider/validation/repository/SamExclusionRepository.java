package com.mivan.provider.validation.repository;

import com.mivan.provider.validation.model.SamExclusionList;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

/**
 * Repository for {@link SamExclusionList}.
 *
 * <p>Java equivalent of {@code MPRVEXC0} paragraph
 * {@code 3100-CHECK-SAM-EXCLUSION}.</p>
 */
@Repository
public interface SamExclusionRepository
        extends JpaRepository<SamExclusionList, Long> {

    @Query("SELECT s FROM SamExclusionList s "
         + "WHERE (s.npi = :npi OR s.taxId = :taxId) "
         + "AND s.reinstateDt IS NULL")
    List<SamExclusionList> findActiveByNpiOrTaxId(
            @Param("npi") String npi, @Param("taxId") String taxId);
}
