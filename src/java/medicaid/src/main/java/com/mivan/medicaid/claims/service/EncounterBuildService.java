package com.mivan.medicaid.claims.service;

import com.mivan.medicaid.claims.model.MedicaidEncounterStaging;
import com.mivan.medicaid.claims.model.MedicaidEligibility;
import com.mivan.medicaid.claims.model.MedicaidLiability;
import com.mivan.medicaid.claims.repository.MedicaidEligibilityRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDate;

/**
 * Builds state MMIS encounter staging records.
 *
 * Java equivalent of COBOL subprogram MMCOENC0.
 * Mirrors paragraphs 3000-GET-CLAIM-DETAIL through 4000-STAGE-ENCOUNTER.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class EncounterBuildService {

    private final MedicaidEligibilityRepository eligibilityRepository;

    /**
     * Builds a MedicaidEncounterStaging record from the computed liability.
     * Applies state-specific MMIS formatting edits before returning.
     * Mirrors MMCOENC0 paragraphs 3200-FORMAT-MMIS-ENCOUNTER
     * and 3300-APPLY-STATE-EDITS.
     *
     * @param claimId   source claim identifier
     * @param liability computed Medicaid liability (from PayerOfLastResortService)
     * @return populated encounter staging record (not yet persisted — caller stages it)
     */
    public MedicaidEncounterStaging buildEncounter(String claimId,
                                                    MedicaidLiability liability,
                                                    MedicaidEligibility eligibility,
                                                    String provNpi,
                                                    LocalDate dosFrom,
                                                    LocalDate dosTo,
                                                    String diag1,
                                                    String procCd) {
        MedicaidEncounterStaging staging = MedicaidEncounterStaging.builder()
                .claimId(claimId)
                .memberId(liability.getMemberId())
                .stateCd(liability.getStateCd())
                .mcoId(eligibility.getMcoId())
                .provNpi(provNpi)
                .dosFrom(dosFrom)
                .dosTo(dosTo)
                .diag1(diag1)
                .procCd(procCd)
                .billedAmt(liability.getBilledAmt())
                .paidAmt(liability.getMedicaidAmt())
                .tplAmt(liability.getTplPaidAmt())
                .status("ST")
                .build();

        validateStateEdits(staging);
        log.info("Encounter built claimId={} status={}", claimId, staging.getStatus());
        return staging;
    }

    private void validateStateEdits(MedicaidEncounterStaging s) {
        // MMCOENC0 paragraph 3300 — mandatory state edit checks
        if (s.getProvNpi() == null || s.getProvNpi().isBlank()) {
            s.setStatus("RJ");
            log.warn("Encounter rejected — missing provNpi for claimId={}", s.getClaimId());
        }
        if (s.getDiag1() == null || s.getDiag1().isBlank()) {
            s.setStatus("RJ");
            log.warn("Encounter rejected — missing diag1 for claimId={}", s.getClaimId());
        }
    }
}
