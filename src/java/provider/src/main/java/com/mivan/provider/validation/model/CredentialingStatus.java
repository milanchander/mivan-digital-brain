package com.mivan.provider.validation.model;

/**
 * Outcome of the credentialing check.
 *
 * <p>COBOL equivalent: the credentialing result returned by {@code MPRVCRD0}
 * (the {@code WS-PRV-CRED-VALID} / {@code CREDENTIALED} 88-level).</p>
 */
public enum CredentialingStatus {
    /** All required credentials present and unexpired. */
    CREDENTIALED,
    /** Provider carries a credential that is expired as of the date of service. */
    EXPIRED,
    /** Provider has no active credentials on file. */
    NOT_CREDENTIALED,
    /** Credentialing could not be determined (data / lookup error). */
    UNKNOWN
}
