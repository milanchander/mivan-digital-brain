package com.mivan.medicaid.claims.service;

import com.mivan.medicaid.claims.model.TplPayerFile;
import com.mivan.medicaid.claims.model.TplResult;
import com.mivan.medicaid.claims.repository.TplPayerRepository;
import com.mivan.medicaid.claims.repository.TplResultRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

/**
 * Identifies third party liability (TPL) payers for Medicaid members.
 *
 * Java equivalent of COBOL subprogram MMCOTPL0.
 *
 * Federal rule — 42 CFR 433.139:
 * Medicaid is always payer of last resort. All other insurers
 * (employer-sponsored, Medicare, private) must pay before Medicaid.
 * MCOs must pursue TPL recovery as a condition of their state contract.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ThirdPartyLiabilityService {

    private final TplPayerRepository tplPayerRepository;
    private final TplResultRepository tplResultRepository;

    /**
     * Identifies all active TPL payers for the member on the DOS and returns
     * the aggregate TPL result. Returns empty if no TPL exists.
     *
     * Mirrors MMCOTPL0 paragraphs 3000-LOOKUP-TPL-PAYERS through 3300-CALCULATE-TPL-TOTAL.
     *
     * @param claimId  claim being processed
     * @param memberId member identifier
     * @return Optional TplResult (empty if no active TPL payers found)
     */
    public Optional<TplResult> identifyTpl(String claimId, String memberId, LocalDate dos) {
        // MMCOTPL0 paragraph 3000 — look up all active TPL payers
        List<TplPayerFile> payers =
                tplPayerRepository.findByIdMemberIdAndStatusCd(memberId, "AC");

        // MMCOTPL0 paragraph 3100 — verify active on DOS
        List<TplPayerFile> activePayers = payers.stream()
                .filter(p -> p.isActiveOn(dos))
                .toList();

        if (activePayers.isEmpty()) {
            log.debug("No active TPL payers for memberId={} dos={}", memberId, dos);
            return Optional.empty();
        }

        // MMCOTPL0 paragraph 3200 — get TPL payment amounts
        // MMCOTPL0 paragraph 3300 — calculate total TPL
        BigDecimal totalPaid = BigDecimal.ZERO;
        String primaryPayerId = null;
        String primaryPayerName = null;

        for (TplPayerFile payer : activePayers) {
            Optional<TplResult> existing = tplResultRepository
                    .findByClaimIdAndStatusCd(claimId, "PD");
            if (existing.isPresent()) {
                totalPaid = totalPaid.add(
                        existing.get().getPaidAmt() != null
                                ? existing.get().getPaidAmt()
                                : BigDecimal.ZERO);
            }
            if (primaryPayerId == null) {
                primaryPayerId = payer.getId().getPayerId();
                primaryPayerName = payer.getPayerName();
            }
        }

        TplResult result = TplResult.builder()
                .claimId(claimId)
                .memberId(memberId)
                .payerId(primaryPayerId)
                .payerName(primaryPayerName)
                .paidAmt(totalPaid)
                .paidDt(LocalDate.now())
                .lastResortAmt(totalPaid)
                .statusCd(totalPaid.compareTo(BigDecimal.ZERO) > 0 ? "PD" : "PE")
                .build();

        TplResult saved = tplResultRepository.save(result);
        log.info("TPL identified claimId={} totalPaid={}", claimId, totalPaid);
        return Optional.of(saved);
    }
}
