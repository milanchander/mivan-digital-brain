package com.mivan.provider.validation.model;

/**
 * Overall outcome of a provider validation run.
 *
 * <p>COBOL equivalent: the {@code WS-PRV-VALID-FLAG}
 * ({@code PROVIDER-VALID} / {@code PROVIDER-INVALID}) in copybook
 * {@code MPRVVLDR}, refined with the specific reason the driver
 * ({@code MPRVVLDR0}) short-circuited.</p>
 */
public enum ProviderValidationStatus {
    /** Provider is credentialed, not excluded, and eligible for payment. */
    VALID,
    /** Provider was found on an exclusion list — payment prohibited. */
    EXCLUDED,
    /** Provider failed credentialing. */
    NOT_CREDENTIALED,
    /** No provider record could be resolved for the NPI. */
    NOT_FOUND,
    /** Validation could not complete due to a processing error. */
    ERROR
}
