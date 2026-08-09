package com.mivan.provider.validation.service;

import com.mivan.provider.validation.model.ProviderSanctionLog;
import com.mivan.provider.validation.model.ProviderValidationResponse;
import com.mivan.provider.validation.model.ProviderValidationStatus;
import com.mivan.provider.validation.repository.ProviderSanctionLogRepository;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * Sanction logging service — the mandatory audit trail.
 *
 * <p>Java equivalent of the {@code MPRVSANL0} subprogram. Writes one
 * {@code PROVIDER_SANCTION_LOG} row for every validation, whether the outcome
 * is clean or an exclusion hit. This method is always called by the
 * orchestrator and must never be skipped.</p>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SanctionLogService {

    private static final String EVENT_VALIDATION = "VALD";
    private static final String EVENT_EXCLUSION = "EXCL";

    private final ProviderSanctionLogRepository sanctionLogRepository;

    /**
     * Persist the audit record for a completed validation.
     *
     * @param result the consolidated validation result
     */
    public void logValidation(ProviderValidationResponse result) {
        String eventCd = result.isExcluded() ? EVENT_EXCLUSION : EVENT_VALIDATION;

        ProviderSanctionLog entry = ProviderSanctionLog.builder()
                .npi(result.getNpi())
                .eventCd(eventCd)
                .validFlag(result.isValid() ? "Y" : "N")
                .exclFlag(result.isExcluded() ? "Y" : "N")
                .denyReason(result.getDenyReason())
                .networkInd(result.getNetworkStatus() == null
                        ? null : result.getNetworkStatus().name())
                .tierCd(result.getTierCd())
                .logTs(LocalDateTime.now())
                .build();

        sanctionLogRepository.save(entry);

        if (result.getStatus() == ProviderValidationStatus.EXCLUDED) {
            log.warn("Sanction log written — NPI {} EXCLUDED ({})",
                    result.getNpi(), result.getExclusionSource());
        } else {
            log.debug("Sanction log written — NPI {} status {}",
                    result.getNpi(), result.getStatus());
        }
    }
}
