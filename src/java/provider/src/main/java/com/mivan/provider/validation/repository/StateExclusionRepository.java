package com.mivan.provider.validation.repository;

import com.mivan.provider.validation.model.StateExclusionList;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

/**
 * Repository for {@link StateExclusionList}.
 *
 * <p>Java equivalent of {@code MPRVEXC0} paragraph
 * {@code 3200-CHECK-STATE-EXCLUSION}.</p>
 */
@Repository
public interface StateExclusionRepository
        extends JpaRepository<StateExclusionList, Long> {

    @Query("SELECT s FROM StateExclusionList s "
         + "WHERE (s.npi = :npi OR s.taxId = :taxId) "
         + "AND s.reinstateDt IS NULL")
    List<StateExclusionList> findActiveByNpiOrTaxId(
            @Param("npi") String npi, @Param("taxId") String taxId);
}
