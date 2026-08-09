package com.mivan.provider.validation.service;

import com.mivan.provider.validation.repository.OigExclusionRepository;
import com.mivan.provider.validation.repository.ProviderMasterRepository;
import com.mivan.provider.validation.repository.SamExclusionRepository;
import com.mivan.provider.validation.repository.StateExclusionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * Exclusion check service.
 *
 * <p>Java equivalent of the {@code MPRVEXC0} subprogram. Screens the provider
 * against every federal and state exclusion source in precedence order:
 * OIG LEIE, SAM, state Medicaid, and the local provider-master flag.</p>
 *
 * <p><strong>COMPLIANCE — CRITICAL:</strong> federal law (42 USC 1320a-7b)
 * prohibits payment by any federal healthcare program to, or on behalf of, a
 * provider who appears on an exclusion list. A single hit blocks payment and
 * this check may never be bypassed.</p>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ExclusionCheckService {

    private final OigExclusionRepository oigExclusionRepository;
    private final SamExclusionRepository samExclusionRepository;
    private final StateExclusionRepository stateExclusionRepository;
    private final ProviderMasterRepository providerMasterRepository;

    /**
     * Screen the provider against all exclusion sources.
     *
     * @param npi   10-digit National Provider Identifier
     * @param taxId provider Tax ID
     * @return the exclusion result (excluded flag + source)
     */
    public ExclusionResult checkExclusions(String npi, String taxId) {
        // 3000 — OIG LEIE
        if (!oigExclusionRepository
                .findByNpiOrTaxIdAndReinstatedDtIsNull(npi, taxId).isEmpty()) {
            log.warn("EXCLUSION HIT — OIG LEIE for NPI {}", npi);
            return new ExclusionResult(true, "OIG-LEIE",
                    "EXCLUDED - OIG LEIE");
        }
        // 3100 — SAM
        if (!samExclusionRepository
                .findActiveByNpiOrTaxId(npi, taxId).isEmpty()) {
            log.warn("EXCLUSION HIT — SAM for NPI {}", npi);
            return new ExclusionResult(true, "SAM",
                    "EXCLUDED - SAM DEBARMENT");
        }
        // 3200 — state Medicaid
        if (!stateExclusionRepository
                .findActiveByNpiOrTaxId(npi, taxId).isEmpty()) {
            log.warn("EXCLUSION HIT — STATE for NPI {}", npi);
            return new ExclusionResult(true, "STATE",
                    "EXCLUDED - STATE MEDICAID");
        }
        // 3300 — local provider-master exclusion flag
        boolean masterFlag = providerMasterRepository.findById(npi)
                .map(p -> "Y".equals(p.getExclFlag()))
                .orElse(false);
        if (masterFlag) {
            log.warn("EXCLUSION HIT — PROV-MSTR flag for NPI {}", npi);
            return new ExclusionResult(true, "PROV-MSTR",
                    "EXCLUDED - MASTER FLAG");
        }
        // 3400 — clean
        return new ExclusionResult(false, null, null);
    }

    /**
     * Result of an exclusion screen.
     *
     * <p>COBOL equivalent: the {@code LS-EXCL-REC} area returned by
     * {@code MPRVEXC0}.</p>
     *
     * @param excluded true when the provider is on any exclusion list
     * @param source   exclusion source (OIG-LEIE, SAM, STATE, PROV-MSTR)
     * @param reason   human-readable deny reason
     */
    public record ExclusionResult(boolean excluded, String source, String reason) {
    }
}
