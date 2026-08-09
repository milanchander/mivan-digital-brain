package com.mivan.provider.validation.service;

import com.mivan.provider.validation.model.ProviderMaster;
import com.mivan.provider.validation.repository.ProviderMasterRepository;
import java.time.LocalDate;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * NPI lookup service.
 *
 * <p>Java equivalent of the {@code MPRVNPI0} subprogram. Resolves an NPI to a
 * provider master record and confirms the provider was active on the date of
 * service (effective on/before the DOS and not terminated before it).</p>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ProviderNpiLookupService {

    private static final String STATUS_ACTIVE = "AC";

    private final ProviderMasterRepository providerMasterRepository;

    /**
     * Look up an active provider valid for the given date of service.
     *
     * @param npi 10-digit National Provider Identifier
     * @param dos date of service
     * @return the provider record if found and active on the DOS
     */
    public Optional<ProviderMaster> lookupProvider(String npi, LocalDate dos) {
        return providerMasterRepository.findByNpiAndStatusCd(npi, STATUS_ACTIVE)
                .filter(p -> isActiveOn(p, dos));
    }

    /** Effective/termination date gate — mirrors {@code 3200}/{@code 3300}. */
    private boolean isActiveOn(ProviderMaster p, LocalDate dos) {
        if (dos == null) {
            return true;
        }
        boolean effectiveOk = p.getEffectiveDt() == null
                || !p.getEffectiveDt().isAfter(dos);
        boolean termOk = p.getTermDt() == null
                || !p.getTermDt().isBefore(dos);
        if (!effectiveOk || !termOk) {
            log.debug("Provider {} not active on {} (eff={}, term={})",
                    npiOf(p), dos, p.getEffectiveDt(), p.getTermDt());
        }
        return effectiveOk && termOk;
    }

    private String npiOf(ProviderMaster p) {
        return p == null ? null : p.getNpi();
    }
}
