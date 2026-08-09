package com.mivan.provider.validation.model;

/**
 * Network participation indicator.
 *
 * <p>COBOL equivalent: the {@code WS-PRV-NETWORK-IND} 88-levels
 * ({@code IN-NETWORK 'INN'} / {@code OUT-OF-NETWORK 'OON'}) in copybook
 * {@code MPRVVLDR}.</p>
 */
public enum NetworkStatus {
    /** In-network ({@code INN}). */
    INN,
    /** Out-of-network ({@code OON}). */
    OON
}
