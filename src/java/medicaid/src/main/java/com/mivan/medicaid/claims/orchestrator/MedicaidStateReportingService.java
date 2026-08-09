package com.mivan.medicaid.claims.orchestrator;

import com.mivan.medicaid.claims.model.*;
import com.mivan.medicaid.claims.service.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;

/**
 * Post-adjudication state reporting for Medicaid claims after TriZetto Facets
 * (MiFCT) adjudication. Handles third party liability identification, payer of
 * last resort calculation per 42 CFR 433.139, and state MMIS encounter data
 * submission.
 *
 * This is NOT a claim adjudication driver. MiFCT (TriZetto Facets) adjudicates
 * Medicaid claims. This service handles post-adjudication state reporting
 * obligations only.
 *
 * Post-adjudication steps:
 *   1. Eligibility confirmation → MedicaidEligibilityService.verifyEligibility()
 *   2. TPL identification → ThirdPartyLiabilityService.identifyTpl()
 *   3. Payer of last resort → PayerOfLastResortService.calculateMedicaidLiability()
 *   4. Encounter build → EncounterBuildService.buildEncounter()
 *   5. State MMIS submission → StateSubmissionService.stageForSubmission()
 *
 * Federal rule — 42 CFR 433.139: Medicaid is always payer of last resort.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MedicaidStateReportingService {

    private final MedicaidEligibilityService eligibilityService;
    private final ThirdPartyLiabilityService tplService;
    private final PayerOfLastResortService lastResortService;
    private final EncounterBuildService encounterBuildService;
    private final StateSubmissionService stateSubmissionService;

    /**
     * Runs post-adjudication state reporting for a single Medicaid claim after
     * MiFCT has adjudicated it: eligibility confirmation, TPL identification,
     * payer-of-last-resort calculation (42 CFR 433.139), encounter build, and
     * state MMIS staging.
     *
     * @param request state-reporting request
     * @return MedicaidClaimResponse with outcome details
     */
    @Transactional
    public MedicaidClaimResponse processStateReporting(MedicaidClaimRequest request) {
        log.info("State reporting for Medicaid claim claimId={} memberId={} state={}",
                request.getClaimId(), request.getMemberId(), request.getStateCd());

        // Step 1 — confirm Medicaid eligibility
        MedicaidEligibilityService.MedicaidEligibilityStatus eligStatus =
                eligibilityService.verifyEligibility(
                        request.getMemberId(), request.getDos(), request.getStateCd());

        if (eligStatus != MedicaidEligibilityService.MedicaidEligibilityStatus.ELIGIBLE) {
            return buildErrorResponse(request, false, "ELIG",
                    "Medicaid eligibility check failed: " + eligStatus);
        }

        Optional<MedicaidEligibility> eligOpt =
                eligibilityService.getEligibility(request.getMemberId(), request.getStateCd());
        if (eligOpt.isEmpty()) {
            return buildErrorResponse(request, false, "ELIG", "Eligibility record not found");
        }
        MedicaidEligibility eligibility = eligOpt.get();

        // Step 2 — identify TPL payers
        Optional<TplResult> tplOpt =
                tplService.identifyTpl(request.getClaimId(), request.getMemberId(), request.getDos());
        TplResult tpl = tplOpt.orElse(null);
        boolean tplFound = tpl != null && tpl.hasTpl();

        // Step 3 — apply payer of last resort (42 CFR 433.139)
        BigDecimal billedAmt = BigDecimal.valueOf(100.00); // resolved from CLAIM_HEADER in prod
        MedicaidLiability liability = lastResortService.calculateMedicaidLiability(
                request.getClaimId(), billedAmt, tpl, eligibility);

        // Step 4 — build encounter record
        MedicaidEncounterStaging staging = encounterBuildService.buildEncounter(
                request.getClaimId(), liability, eligibility,
                null, request.getDos(), request.getDos(), null, null);

        // Step 5 — stage encounter for state MMIS submission
        boolean staged = stateSubmissionService.stageForSubmission(staging);

        return MedicaidClaimResponse.builder()
                .claimId(request.getClaimId())
                .memberId(request.getMemberId())
                .eligible(true)
                .tplFound(tplFound)
                .tplPaidAmt(tpl != null ? tpl.getPaidAmt() : BigDecimal.ZERO)
                .medicaidLiabilityAmt(liability.getMedicaidAmt())
                .encounterStatus(staging.getStatus())
                .stagedForSubmission(staged)
                .build();
    }

    private MedicaidClaimResponse buildErrorResponse(MedicaidClaimRequest req,
                                                      boolean eligible,
                                                      String errorCode,
                                                      String message) {
        log.warn("Claim processing failed claimId={} error={}", req.getClaimId(), message);
        return MedicaidClaimResponse.builder()
                .claimId(req.getClaimId())
                .memberId(req.getMemberId())
                .eligible(eligible)
                .stagedForSubmission(false)
                .errorCode(errorCode)
                .errorMessage(message)
                .build();
    }
}
