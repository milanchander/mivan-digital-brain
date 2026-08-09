package com.mivan.provider.validation.model;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDate;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Consolidated result of a provider-validation run.
 *
 * <p>COBOL equivalent: the {@code WS-PRV-VALIDATION} area in copybook
 * {@code MPRVVLDR}, assembled across the five steps of {@code MPRVVLDR0}
 * and handed to {@code MPRVSANL0} for logging.</p>
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "Provider validation result")
public class ProviderValidationResponse {

    @Schema(description = "Provider NPI evaluated", example = "1234567893")
    private String npi;

    @Schema(description = "Date of service evaluated", example = "2026-08-01")
    private LocalDate dateOfService;

    @Schema(description = "Overall validation outcome")
    private ProviderValidationStatus status;

    @Schema(description = "True when the provider may be paid for this claim")
    private boolean valid;

    @Schema(description = "Credentialing outcome")
    private CredentialingStatus credentialingStatus;

    @Schema(description = "Whether the provider appears on any exclusion list")
    private boolean excluded;

    @Schema(description = "Exclusion source when excluded (OIG-LEIE, SAM, STATE, PROV-MSTR)")
    private String exclusionSource;

    @Schema(description = "Network participation indicator")
    private NetworkStatus networkStatus;

    @Schema(description = "Network tier code", example = "T1")
    private String tierCd;

    @Schema(description = "Fee schedule pointer", example = "FS-COMM-01")
    private String feeScheduleId;

    @Schema(description = "Human-readable deny reason when not valid")
    private String denyReason;
}
