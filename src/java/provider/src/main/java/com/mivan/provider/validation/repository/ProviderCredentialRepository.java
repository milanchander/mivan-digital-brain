package com.mivan.provider.validation.repository;

import com.mivan.provider.validation.model.ProviderCredential;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/**
 * Repository for {@link ProviderCredential}.
 *
 * <p>Java equivalent of the credential read in {@code MPRVCRD0} paragraph
 * {@code 3000-GET-CREDENTIALS}.</p>
 */
@Repository
public interface ProviderCredentialRepository
        extends JpaRepository<ProviderCredential, Long> {

    /** All active credential rows for a provider. */
    List<ProviderCredential> findByNpiAndStatusCd(String npi, String statusCd);
}
