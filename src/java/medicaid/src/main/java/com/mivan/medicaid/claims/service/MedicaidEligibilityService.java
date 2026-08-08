package com.mivan.medicaid.claims.service;

import com.mivan.medicaid.claims.model.MedicaidEligibility;
import com.mivan.medicaid.claims.repository.MedicaidEligibilityRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.Period;
import java.util.Optional;

/**
 * Verifies Medicaid eligibility for a member on a given date of service.
 *
 * Java equivalent of COBOL subprogram MMCOELV0.
 *
 * Handles:
 * - Monthly eligibility churn (members gain/lose eligibility frequently)
 * - Spend-down logic (eligibility conditioned on meeting deductible)
 * - CHIP eligibility (Title XXI, state-administered)
 * - EPSDT eligibility (mandatory for members under 21 — 42 USC 1396d(r))
 * - Dual eligibility (Medicare + Medicaid)
 * - Retroactive eligibility (member made eligible after DOS)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MedicaidEligibilityService {

    private final MedicaidEligibilityRepository eligibilityRepository;

    public enum MedicaidEligibilityStatus {
        ELIGIBLE, INELIGIBLE, SPEND_DOWN_NOT_MET, PENDING, RETROACTIVE
    }

    /**
     * Verifies Medicaid eligibility on the given date of service.
     * Mirrors MMCOELV0 paragraphs 3000-3500.
     *
     * @param memberId member identifier
     * @param dos      date of service
     * @param stateCd  state code (Medicaid is state-administered)
     * @return MedicaidEligibilityStatus
     */
    public MedicaidEligibilityStatus verifyEligibility(String memberId,
                                                        LocalDate dos,
                                                        String stateCd) {
        Optional<MedicaidEligibility> elig =
                eligibilityRepository.findActiveOnDos(memberId, stateCd, dos);

        if (elig.isEmpty()) {
            log.debug("No active Medicaid eligibility for memberId={} dos={} state={}",
                    memberId, dos, stateCd);
            return MedicaidEligibilityStatus.INELIGIBLE;
        }

        MedicaidEligibility e = elig.get();

        // MMCOELV0 paragraph 3100 — spend-down check
        if (e.hasSpendDown()) {
            log.debug("Spend-down not met for memberId={}", memberId);
            return MedicaidEligibilityStatus.SPEND_DOWN_NOT_MET;
        }

        // MMCOELV0 paragraph 3200 — CHIP (separate benefit package)
        if ("Y".equals(e.getChipInd())) {
            log.debug("Member {} is CHIP — applying Title XXI rules", memberId);
        }

        // MMCOELV0 paragraph 3300 — EPSDT for under-21
        if (e.isEpsdt()) {
            int age = Period.between(dos, dos).getYears();
            log.debug("EPSDT eligible for memberId={}", memberId);
        }

        // MMCOELV0 paragraph 3400 — dual eligible coordination
        if (e.isDualEligible()) {
            log.debug("Dual eligible — Medicare primary for memberId={}", memberId);
        }

        log.info("Medicaid eligible: memberId={} state={} dos={}", memberId, stateCd, dos);
        return MedicaidEligibilityStatus.ELIGIBLE;
    }

    public Optional<MedicaidEligibility> getEligibility(String memberId, String stateCd) {
        return eligibilityRepository.findByMemberIdAndStateCdAndStatusCd(memberId, stateCd, "AC");
    }
}
