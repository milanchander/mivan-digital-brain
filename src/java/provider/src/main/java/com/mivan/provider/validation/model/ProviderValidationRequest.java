package com.mivan.provider.validation.model;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import java.time.LocalDate;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Inbound provider-validation request.
 *
 * <p>COBOL equivalent: the {@code WS-PRV-NPI} / {@code WS-PRV-DOS} inputs the
 * driver {@code MPRVVLDR0} populates from the inbound claim.</p>
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "Provider validation request (NPI + date of service)")
public class ProviderValidationRequest {

    @NotBlank
    @Pattern(regexp = "\\d{10}", message = "NPI must be 10 digits")
    @Schema(description = "10-digit National Provider Identifier",
            example = "1234567893")
    private String npi;

    @Schema(description = "Date of service", example = "2026-08-01")
    private LocalDate dateOfService;
}
