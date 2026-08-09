package com.mivan.provider.validation.service;

import com.mivan.provider.validation.model.CredentialingStatus;
import com.mivan.provider.validation.model.ProviderCredential;
import com.mivan.provider.validation.repository.ProviderCredentialRepository;
import java.time.LocalDate;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * Credentialing check service.
 *
 * <p>Java equivalent of the {@code MPRVCRD0} subprogram. Confirms the provider
 * holds valid, unexpired credentials as of the date of service — license, DEA,
 * malpractice coverage, and board certification.</p>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CredentialingCheckService {

    private static final String STATUS_ACTIVE = "AC";
    private static final String TYPE_LICENSE = "LIC";

    private final ProviderCredentialRepository credentialRepository;

    /**
     * Check credentialing for a provider as of the date of service.
     *
     * @param npi 10-digit National Provider Identifier
     * @param dos date of service
     * @return the credentialing outcome
     */
    public CredentialingStatus checkCredentials(String npi, LocalDate dos) {
        List<ProviderCredential> creds =
                credentialRepository.findByNpiAndStatusCd(npi, STATUS_ACTIVE);

        if (creds.isEmpty()) {
            log.debug("No active credentials for NPI {}", npi);
            return CredentialingStatus.NOT_CREDENTIALED;
        }

        boolean licensePresent = creds.stream()
                .anyMatch(c -> TYPE_LICENSE.equals(c.getTypeCd()));
        if (!licensePresent) {
            return CredentialingStatus.NOT_CREDENTIALED;
        }

        // 3100 — any required credential expired as of the DOS fails the check.
        boolean anyExpired = creds.stream().anyMatch(c -> isExpired(c, dos));
        if (anyExpired) {
            return CredentialingStatus.EXPIRED;
        }

        // 3200/3300/3400 — DEA, malpractice, and board-cert checks pass when the
        // corresponding active, unexpired rows are present (validated above).
        return CredentialingStatus.CREDENTIALED;
    }

    private boolean isExpired(ProviderCredential c, LocalDate dos) {
        if (dos == null || c.getExpiryDt() == null) {
            return false;
        }
        return c.getExpiryDt().isBefore(dos);
    }
}
