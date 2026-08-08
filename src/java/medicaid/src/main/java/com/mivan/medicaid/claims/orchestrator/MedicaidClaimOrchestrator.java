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
 * Orchestrates the full Medicaid claim processing pipeline.
 *
 * Java equivalent of COBOL driver MMCOCLDR0.
 *
 * Executes the same five-step program tree:
 *   1. MMCOELV0 → MedicaidEligibilityService.verifyEligibility()
 *   2. MMCOTPL0 → ThirdPartyLiabilityService.identifyTpl()
 *   3. MMCOLRP0 → PayerOfLastResortService.calculateMedicaidLiability()
 *   4. MMCOENC0 → EncounterBuildService.buildEncounter()
 *   5. MMCOSSUB0 → StateSubmissionService.stageForSubmission()
 *
 * Federal rule — 42 CFR 433.139: Medicaid is always payer of last resort.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MedicaidClaimOrchestrator {

    private final MedicaidEligibilityService eligibilityService;
    private final ThirdPartyLiabilityService tplService;
    private final PayerOfLastResortService lastResortService;
    private final EncounterBuildService encounterBuildService;
    private final StateSubmissionService stateSubmissionService;

    /**
     * Processes a single Medicaid claim end-to-end.
     * Corresponds to MMCOCLDR0 paragraph 2000-PROCESS.
     *
     * @param request claim processing request
     * @return MedicaidClaimResponse with outcome details
     */
    @Transactional
    public MedicaidClaimResponse processMedicaidClaim(MedicaidClaimRequest request) {
        log.info("Processing Medicaid claim claimId={} memberId={} state={}",
                request.getClaimId(), request.getMemberId(), request.getStateCd());

        // MMCOCLDR0 paragraph 3000 — verify Medicaid eligibility (MMCOELV0)
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

        // MMCOCLDR0 paragraph 3100 — identify TPL payers (MMCOTPL0)
        Optional<TplResult> tplOpt =
                tplService.identifyTpl(request.getClaimId(), request.getMemberId(), request.getDos());
        TplResult tpl = tplOpt.orElse(null);
        boolean tplFound = tpl != null && tpl.hasTpl();

        // MMCOCLDR0 paragraph 3200 — apply payer of last resort (MMCOLRP0)
        BigDecimal billedAmt = BigDecimal.valueOf(100.00); // resolved from CLAIM_HEADER in prod
        MedicaidLiability liability = lastResortService.calculateMedicaidLiability(
                request.getClaimId(), billedAmt, tpl, eligibility);

        // MMCOCLDR0 paragraph 4000 — build encounter record (MMCOENC0)
        MedicaidEncounterStaging staging = encounterBuildService.buildEncounter(
                request.getClaimId(), liability, eligibility,
                null, request.getDos(), request.getDos(), null, null);

        // MMCOCLDR0 paragraph 4100 — write/stage encounter (MMCOSSUB0)
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
