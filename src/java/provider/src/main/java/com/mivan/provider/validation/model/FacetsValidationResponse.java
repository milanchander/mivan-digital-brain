package com.mivan.provider.validation.model;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Facets-specific validation response. Maps internal ProviderValidationResponse
 * to Facets-compatible format.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "Facets provider validation response")
public class FacetsValidationResponse {

    @Schema(description = "Facets transaction ID echoed from the request", example = "FCT-20260809-000123")
    private String facetsTransactionId;

    @Schema(description = "Provider NPI evaluated", example = "1234567893")
    private String npi;

    @Schema(description = "Overall validation outcome")
    private ProviderValidationStatus status;

    @Schema(description = "Network participation indicator (INN / OON)")
    private NetworkStatus networkStatus;

    @Schema(description = "Network tier code", example = "T1")
    private String tierCode;

    @Schema(description = "Fee schedule pointer", example = "FS-COMM-01")
    private String feeScheduleId;

    @Schema(description = "True when credentialing is valid")
    private boolean credentialingValid;

    @Schema(description = "Whether the provider appears on any exclusion list")
    private boolean excluded;

    @Schema(description = "Exclusion source when excluded (OIG-LEIE, SAM, STATE, PROV-MSTR)")
    private String exclusionSource;

    @Schema(description = "Human-readable deny reason when not valid")
    private String denyReason;

    @Schema(description = "Timestamp the validation was performed")
    private LocalDateTime validatedAt;
}
