package com.mivan.provider.validation.service;

import com.mivan.provider.validation.model.NetworkContract;
import com.mivan.provider.validation.model.NetworkStatus;
import com.mivan.provider.validation.repository.NetworkContractRepository;
import java.time.LocalDate;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * Network verification service.
 *
 * <p>Java equivalent of the {@code MPRVNET0} subprogram. Determines the
 * provider's network participation for the date of service and returns the
 * network indicator (INN / OON), tier, and fee schedule pointer.</p>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class NetworkVerificationService {

    private static final String STATUS_ACTIVE = "AC";

    private final NetworkContractRepository networkContractRepository;

    /**
     * Verify network participation for a provider on the date of service.
     *
     * @param npi 10-digit National Provider Identifier
     * @param dos date of service
     * @return the network verification result
     */
    public NetworkVerificationResult verifyNetwork(String npi, LocalDate dos) {
        List<NetworkContract> contracts = networkContractRepository
                .findByNpiAndStatusCdOrderByEffectiveDtDesc(npi, STATUS_ACTIVE);

        NetworkContract active = contracts.stream()
                .filter(c -> isEffectiveOn(c, dos))
                .findFirst()
                .orElse(null);

        if (active == null) {
            log.debug("No active network contract for NPI {} on {}", npi, dos);
            return new NetworkVerificationResult(
                    NetworkStatus.OON, null, null, false);
        }

        boolean acceptsNew = "Y".equals(active.getAcceptNewPat());
        return new NetworkVerificationResult(
                NetworkStatus.INN,
                active.getTierCd(),
                active.getFeeSchedId(),
                acceptsNew);
    }

    private boolean isEffectiveOn(NetworkContract c, LocalDate dos) {
        if (dos == null) {
            return true;
        }
        boolean effectiveOk = c.getEffectiveDt() == null
                || !c.getEffectiveDt().isAfter(dos);
        boolean termOk = c.getTermDt() == null
                || !c.getTermDt().isBefore(dos);
        return effectiveOk && termOk;
    }

    /**
     * Result of a network verification.
     *
     * <p>COBOL equivalent: the {@code LS-NETWORK-IND} / {@code LS-TIER-CD} /
     * {@code LS-FEE-SCHED-ID} outputs of {@code MPRVNET0}.</p>
     *
     * @param networkStatus     INN or OON
     * @param tierCd            network tier code (null when OON)
     * @param feeScheduleId     fee schedule pointer (null when OON)
     * @param acceptingPatients whether the provider accepts new patients
     */
    public record NetworkVerificationResult(
            NetworkStatus networkStatus,
            String tierCd,
            String feeScheduleId,
            boolean acceptingPatients) {
    }
}
