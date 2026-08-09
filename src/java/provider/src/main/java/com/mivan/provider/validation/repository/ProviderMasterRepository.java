package com.mivan.provider.validation.repository;

import com.mivan.provider.validation.model.ProviderMaster;
import java.time.LocalDate;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/**
 * Repository for {@link ProviderMaster}.
 *
 * <p>Java equivalent of the {@code PROV-MSTR} VSAM keyed read plus the DB2
 * fallback in {@code MPRVNPI0}.</p>
 */
@Repository
public interface ProviderMasterRepository extends JpaRepository<ProviderMaster, String> {

    /** Active-record read by NPI. */
    Optional<ProviderMaster> findByNpiAndStatusCd(String npi, String statusCd);

    /**
     * Date-of-service aware read: provider effective on or before the DOS and
     * either open-ended or terminated after it.
     */
    Optional<ProviderMaster> findByNpiAndEffectiveDtBeforeAndTermDtAfter(
            String npi, LocalDate effectiveBefore, LocalDate termAfter);
}
