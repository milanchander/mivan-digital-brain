package com.mivan.provider.validation.repository;

import com.mivan.provider.validation.model.ProviderSanctionLog;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/**
 * Repository for {@link ProviderSanctionLog}.
 *
 * <p>Java equivalent of the audit-trail insert in {@code MPRVSANL0} paragraph
 * {@code 3100-WRITE-SANCTION-LOG}.</p>
 */
@Repository
public interface ProviderSanctionLogRepository
        extends JpaRepository<ProviderSanctionLog, Long> {

    /** Full sanction / validation history for a provider, newest first. */
    List<ProviderSanctionLog> findByNpiOrderByLogTsDesc(String npi);
}
