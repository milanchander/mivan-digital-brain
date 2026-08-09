package com.mivan.provider.validation.orchestrator;

import com.mivan.provider.validation.model.CredentialingStatus;
import com.mivan.provider.validation.model.FacetsValidationRequest;
import com.mivan.provider.validation.model.FacetsValidationResponse;
import com.mivan.provider.validation.model.NetworkStatus;
import com.mivan.provider.validation.model.ProviderMaster;
import com.mivan.provider.validation.model.ProviderValidationResponse;
import com.mivan.provider.validation.model.ProviderValidationStatus;
import com.mivan.provider.validation.service.CredentialingCheckService;
import com.mivan.provider.validation.service.ExclusionCheckService;
import com.mivan.provider.validation.service.ExclusionCheckService.ExclusionResult;
import com.mivan.provider.validation.service.NetworkVerificationService;
import com.mivan.provider.validation.service.NetworkVerificationService.NetworkVerificationResult;
import com.mivan.provider.validation.service.ProviderNpiLookupService;
import com.mivan.provider.validation.service.SanctionLogService;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * Provider validation orchestrator.
 *
 * <p>Java equivalent of the {@code MPRVVLDR0} driver program. Runs the
 * five-step provider validation sequence in the same order as the COBOL
 * program tree:</p>
 *
 * <ol>
 *   <li>{@code MPRVNPI0}  — NPI lookup</li>
 *   <li>{@code MPRVCRD0}  — credentialing check</li>
 *   <li>{@code MPRVEXC0}  — exclusion check (short-circuits on a hit)</li>
 *   <li>{@code MPRVNET0}  — network verification</li>
 *   <li>{@code MPRVSANL0} — sanction logging (always runs)</li>
 * </ol>
 *
 * <p><strong>Compliance:</strong> as in {@code MPRVVLDR0}, an exclusion hit
 * short-circuits the sequence and blocks payment, and the sanction log is
 * written for every outcome.</p>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ProviderValidationOrchestrator {

    private final ProviderNpiLookupService npiLookupService;
    private final CredentialingCheckService credentialingService;
    private final ExclusionCheckService exclusionService;
    private final NetworkVerificationService networkService;
    private final SanctionLogService sanctionLogService;

    /**
     * Validate a provider for payment on a given date of service.
     *
     * @param npi 10-digit National Provider Identifier
     * @param dos date of service
     * @return the consolidated validation result
     */
    public ProviderValidationResponse validateProvider(String npi, LocalDate dos) {
        ProviderValidationResponse.ProviderValidationResponseBuilder result =
                ProviderValidationResponse.builder()
                        .npi(npi)
                        .dateOfService(dos);

        // Step 1 — NPI lookup (MPRVNPI0).
        Optional<ProviderMaster> providerOpt =
                npiLookupService.lookupProvider(npi, dos);
        if (providerOpt.isEmpty()) {
            ProviderValidationResponse notFound = result
                    .status(ProviderValidationStatus.NOT_FOUND)
                    .valid(false)
                    .denyReason("PROVIDER NOT FOUND")
                    .build();
            sanctionLogService.logValidation(notFound);   // Step 5 always runs.
            return notFound;
        }
        ProviderMaster provider = providerOpt.get();

        // Step 2 — credentialing (MPRVCRD0).
        CredentialingStatus credStatus =
                credentialingService.checkCredentials(npi, dos);
        result.credentialingStatus(credStatus);

        // Step 3 — exclusions (MPRVEXC0). Short-circuit on a hit.
        ExclusionResult exclusion =
                exclusionService.checkExclusions(npi, provider.getTaxId());
        if (exclusion.excluded()) {
            ProviderValidationResponse excluded = result
                    .status(ProviderValidationStatus.EXCLUDED)
                    .valid(false)
                    .excluded(true)
                    .exclusionSource(exclusion.source())
                    .denyReason(exclusion.reason())
                    .build();
            sanctionLogService.logValidation(excluded);   // Step 5 always runs.
            return excluded;
        }
        result.excluded(false);

        // Step 4 — network verification (MPRVNET0).
        NetworkVerificationResult network =
                networkService.verifyNetwork(npi, dos);
        result.networkStatus(network.networkStatus())
                .tierCd(network.tierCd())
                .feeScheduleId(network.feeScheduleId());

        // Consolidate outcome.
        boolean credentialed = credStatus == CredentialingStatus.CREDENTIALED;
        ProviderValidationResponse response;
        if (credentialed) {
            response = result
                    .status(ProviderValidationStatus.VALID)
                    .valid(true)
                    .build();
        } else {
            response = result
                    .status(ProviderValidationStatus.NOT_CREDENTIALED)
                    .valid(false)
                    .denyReason("CREDENTIALING FAILED: " + credStatus)
                    .build();
        }
        if (network.networkStatus() == NetworkStatus.OON) {
            log.debug("Provider {} is out-of-network on {}", npi, dos);
        }

        // Step 5 — sanction logging (MPRVSANL0), always runs.
        sanctionLogService.logValidation(response);
        return response;
    }

    /**
     * Facets integration method. MiFCT calls this endpoint via REST API
     * (Option A — direct HTTP) after LOB routing determines claim is MA or
     * Medicaid. Same underlying validation as commercial claims through MiCPS —
     * provider validation is LOB-agnostic.
     *
     * @param request the Facets-specific validation request
     * @return the validation result in Facets-compatible format
     */
    public FacetsValidationResponse validateProviderForFacets(FacetsValidationRequest request) {
        log.info("Facets provider validation — txnId={} npi={} lob={} claimId={}",
                request.getFacetsTransactionId(), request.getNpi(),
                request.getLobCode(), request.getClaimId());

        LocalDate dos = request.getDateOfService() == null
                ? LocalDate.now() : request.getDateOfService();

        ProviderValidationResponse result = validateProvider(request.getNpi(), dos);

        return FacetsValidationResponse.builder()
                .facetsTransactionId(request.getFacetsTransactionId())
                .npi(result.getNpi())
                .status(result.getStatus())
                .networkStatus(result.getNetworkStatus())
                .tierCode(result.getTierCd())
                .feeScheduleId(result.getFeeScheduleId())
                .credentialingValid(result.getCredentialingStatus() == CredentialingStatus.CREDENTIALED)
                .excluded(result.isExcluded())
                .exclusionSource(result.getExclusionSource())
                .denyReason(result.getDenyReason())
                .validatedAt(LocalDateTime.now())
                .build();
    }
}
