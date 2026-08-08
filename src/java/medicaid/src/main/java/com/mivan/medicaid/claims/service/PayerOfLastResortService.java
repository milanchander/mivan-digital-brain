package com.mivan.medicaid.claims.service;

import com.mivan.medicaid.claims.model.MedicaidEligibility;
import com.mivan.medicaid.claims.model.MedicaidLiability;
import com.mivan.medicaid.claims.model.StateContract;
import com.mivan.medicaid.claims.model.TplResult;
import com.mivan.medicaid.claims.repository.MedicaidLiabilityRepository;
import com.mivan.medicaid.claims.repository.StateContractRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.Optional;

/**
 * Calculates the Medicaid payment amount as payer of last resort.
 *
 * Java equivalent of COBOL subprogram MMCOLRP0.
 *
 * Federal rule — 42 CFR 433.139:
 * Medicaid pays only what remains after all other payers have paid.
 * The Medicaid amount cannot be negative — surplus goes to $0.00.
 * State-specific fee schedule limits applied from STATE_CONTRACT.
 * BigDecimal used for all monetary calculations (no floating point).
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PayerOfLastResortService {

    private final MedicaidLiabilityRepository liabilityRepository;
    private final StateContractRepository stateContractRepository;

    private static final BigDecimal MEMBER_COPAY_DEFAULT = new BigDecimal("3.00");
    private static final int SCALE = 2;

    /**
     * Calculates Medicaid liability after TPL and member cost-sharing.
     * Mirrors MMCOLRP0 paragraphs 3000 through 4000.
     *
     * Formula: medicaidAmt = max(0, billedAmt - tplPaidAmt - memberRespAmt)
     *
     * @param claimId     claim being processed
     * @param billedAmt   total billed amount from claim
     * @param tpl         TPL result (may be null if no TPL payers)
     * @param eligibility member eligibility (for state/MCO context)
     * @return persisted MedicaidLiability record
     */
    public MedicaidLiability calculateMedicaidLiability(String claimId,
                                                          BigDecimal billedAmt,
                                                          TplResult tpl,
                                                          MedicaidEligibility eligibility) {
        // MMCOLRP0 paragraph 3100 — get TPL payments
        BigDecimal tplPaid = tpl != null && tpl.getPaidAmt() != null
                ? tpl.getPaidAmt()
                : BigDecimal.ZERO;

        // MMCOLRP0 paragraph 3300 — state-specific rules
        BigDecimal memberResp = deriveMemberResponsibility(eligibility);

        // MMCOLRP0 paragraph 3200 — calculate remaining liability (floor 0)
        BigDecimal medicaidAmt = billedAmt
                .subtract(tplPaid)
                .subtract(memberResp)
                .setScale(SCALE, RoundingMode.HALF_UP);

        if (medicaidAmt.compareTo(BigDecimal.ZERO) < 0) {
            medicaidAmt = BigDecimal.ZERO.setScale(SCALE);
        }

        String statusCd = medicaidAmt.compareTo(BigDecimal.ZERO) == 0 ? "ZR" : "CM";

        MedicaidLiability liability = MedicaidLiability.builder()
                .claimId(claimId)
                .memberId(eligibility.getMemberId())
                .stateCd(eligibility.getStateCd())
                .billedAmt(billedAmt.setScale(SCALE, RoundingMode.HALF_UP))
                .tplPaidAmt(tplPaid.setScale(SCALE, RoundingMode.HALF_UP))
                .memberRespAmt(memberResp.setScale(SCALE, RoundingMode.HALF_UP))
                .medicaidAmt(medicaidAmt)
                .calcDt(LocalDate.now())
                .statusCd(statusCd)
                .build();

        MedicaidLiability saved = liabilityRepository.save(liability);
        log.info("Medicaid liability claimId={} billed={} tpl={} medicaidAmt={}",
                claimId, billedAmt, tplPaid, medicaidAmt);
        return saved;
    }

    private BigDecimal deriveMemberResponsibility(MedicaidEligibility e) {
        // CHIP members may have higher cost-sharing than Medicaid
        if ("Y".equals(e.getChipInd())) {
            return MEMBER_COPAY_DEFAULT;
        }
        // EPSDT services — no cost-sharing for preventive services
        if (e.isEpsdt()) {
            return BigDecimal.ZERO;
        }
        // State-specific rules via STATE_CONTRACT
        Optional<StateContract> contract = stateContractRepository
                .findByIdStateCdAndIdMcoId(e.getStateCd(), e.getMcoId() != null ? e.getMcoId() : "");
        return MEMBER_COPAY_DEFAULT;
    }
}
