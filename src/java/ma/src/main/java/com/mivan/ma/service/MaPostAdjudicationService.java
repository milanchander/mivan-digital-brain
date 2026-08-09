package com.mivan.ma.service;

import com.mivan.ma.model.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Post-adjudication processing for Medicare Advantage claims after TriZetto
 * Facets (MiFCT) adjudication. Handles CMS EDPS encounter data submission, HCC
 * diagnosis validation, and RAF score calculation. Called by MiFCT via REST API
 * after claim adjudication is complete.
 *
 * This is NOT a claim adjudication driver. MiFCT (TriZetto Facets) adjudicates
 * MA claims. This service handles post-adjudication CMS reporting obligations
 * only.
 *
 * Post-adjudication steps:
 *   1. Eligibility confirmation → MaEligibilityService.isEligible()
 *   2. HCC diagnosis validation → HccValidationService.validateHccCodes()
 *   3. RAF score calculation → RafCalculationService.calculateRaf()
 *   4. Encounter record staging → EncounterBuilderService.buildAndStageEncounters()
 *   5. CMS EDPS submission → EdpsSubmissionService.submitToEdps()
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MaPostAdjudicationService {

    private final MaEligibilityService eligibilityService;
    private final HccValidationService hccValidationService;
    private final RafCalculationService rafCalculationService;
    private final EncounterBuilderService encounterBuilderService;
    private final EdpsSubmissionService edpsSubmissionService;

    /**
     * Runs post-adjudication CMS reporting for a single member after MiFCT has
     * adjudicated the claim: eligibility confirmation, HCC validation, RAF
     * calculation, encounter staging, and EDPS submission.
     */
    @Transactional
    public EncounterProcessingResult processPostAdjudication(String mbi,
                                                    String contractId,
                                                    String paymentYear,
                                                    List<MaHccRecord> hccRecords) {
        log.info("Processing mbi={} contractId={} paymentYear={}", mbi, contractId, paymentYear);

        // Step 1 — Eligibility
        Optional<MaEnrollment> enrollmentOpt = eligibilityService.getEnrollment(mbi, contractId);
        if (enrollmentOpt.isEmpty()
                || !eligibilityService.isEligible(mbi, contractId, LocalDate.now())) {
            return EncounterProcessingResult.builder()
                    .mbi(mbi).contractId(contractId)
                    .eligible(false).submissionStatus("PE")
                    .errorCode("ELIG").errorMessage("Member not eligible")
                    .build();
        }
        MaEnrollment enrollment = enrollmentOpt.get();

        // Step 2 — HCC Validation
        List<MaHccRecord> validated =
                hccValidationService.validateHccCodes(mbi, paymentYear, hccRecords);
        List<MaHccRecord> validOnly = validated.stream()
                .filter(h -> "VA".equals(h.getValidationStatus()))
                .toList();

        if (validOnly.isEmpty()) {
            return EncounterProcessingResult.builder()
                    .mbi(mbi).contractId(contractId)
                    .eligible(true).hccValid(false).submissionStatus("PE")
                    .errorCode("NOHC").errorMessage("No valid HCC codes")
                    .build();
        }

        // Step 3 — RAF Calculation
        MaRafScore rafScore = rafCalculationService.calculateRaf(enrollment, validOnly, paymentYear);

        // Step 4 — Encounter Build
        List<MaEncounterStaging> staged =
                encounterBuilderService.buildAndStageEncounters(enrollment, validOnly, rafScore);

        // Step 5 — EDPS Submission
        List<MaEncounterStaging> submitted = edpsSubmissionService.submitToEdps(staged);

        String encounterId = submitted.isEmpty() ? null : submitted.get(0).getEncounterId();
        return EncounterProcessingResult.builder()
                .mbi(mbi).hicn(enrollment.getHicn()).contractId(contractId)
                .encounterId(encounterId)
                .eligible(true).hccValid(true)
                .rafTotal(rafScore.getTotalRaf().toPlainString())
                .submissionStatus(submitted.isEmpty() ? "PE" : "SU")
                .build();
    }

    /**
     * Batch entry point — runs post-adjudication reporting for a list of members
     * and returns an aggregate summary.
     */
    @Transactional
    public EncounterBatchSummary processBatch(List<MemberEncounterRequest> requests) {
        List<EncounterProcessingResult> errors = new ArrayList<>();
        int eligible = 0, ineligible = 0, hccValid = 0, hccReject = 0,
                encountered = 0, submitted = 0, errorCount = 0;

        for (MemberEncounterRequest req : requests) {
            EncounterProcessingResult result =
                    processPostAdjudication(req.mbi(), req.contractId(), req.paymentYear(), req.hccRecords());
            if (!result.isEligible()) {
                ineligible++;
            } else {
                eligible++;
                if (!result.isHccValid()) {
                    hccReject++;
                } else {
                    hccValid++;
                    encountered++;
                    if (result.isSuccess()) submitted++;
                }
            }
            if (result.getErrorCode() != null) {
                errorCount++;
                errors.add(result);
            }
        }

        return EncounterBatchSummary.builder()
                .inputCount(requests.size())
                .eligibleCount(eligible).ineligibleCount(ineligible)
                .hccValidCount(hccValid).hccRejectCount(hccReject)
                .encounterCount(encountered).submitCount(submitted)
                .errorCount(errorCount).errors(errors)
                .build();
    }

    /** Lightweight request record for batch processing. */
    public record MemberEncounterRequest(
            String mbi, String contractId, String paymentYear,
            List<MaHccRecord> hccRecords) {}
}
