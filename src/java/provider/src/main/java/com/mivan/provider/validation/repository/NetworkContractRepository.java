package com.mivan.provider.validation.repository;

import com.mivan.provider.validation.model.NetworkContract;
import java.time.LocalDate;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/**
 * Repository for {@link NetworkContract}.
 *
 * <p>Java equivalent of the contract read in {@code MPRVNET0} paragraph
 * {@code 3000-LOOKUP-NETWORK-CONTRACT}.</p>
 */
@Repository
public interface NetworkContractRepository
        extends JpaRepository<NetworkContract, Long> {

    /**
     * Contracts effective on or before the DOS and terminating after it.
     * Most-recent effective date first.
     */
    List<NetworkContract> findByNpiAndEffectiveDtBeforeAndTermDtAfter(
            String npi, LocalDate effectiveBefore, LocalDate termAfter);

    /** Active contracts for a provider, most-recent effective date first. */
    List<NetworkContract> findByNpiAndStatusCdOrderByEffectiveDtDesc(
            String npi, String statusCd);
}
