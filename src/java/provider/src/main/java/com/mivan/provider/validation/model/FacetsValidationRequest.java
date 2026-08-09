package com.mivan.provider.validation.model;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDate;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Facets-specific provider validation request. Called by MiFCT (TriZetto Facets)
 * after LOB routing for MA and Medicaid claims. Uses Option A direct REST API
 * integration.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "Facets provider validation request (Option A direct REST integration)")
public class FacetsValidationRequest {

    @Schema(description = "Facets transaction ID for audit correlation", example = "FCT-20260809-000123")
    private String facetsTransactionId;

    @Schema(description = "10-digit National Provider Identifier", example = "1234567893")
    private String npi;

    @Schema(description = "Provider Tax ID", example = "123456789")
    private String taxId;

    @Schema(description = "Date of service", example = "2026-08-01")
    private LocalDate dateOfService;

    @Schema(description = "Line of business code — MA or MC", example = "MA")
    private String lobCode;

    @Schema(description = "Facets claim ID", example = "CLM20260809001")
    private String claimId;

    @Schema(description = "Plan ID", example = "H1234-001")
    private String planId;
}
