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
 * Orchestrates the full MA encounter data processing pipeline.
 *
 * Java equivalent of COBOL driver MAENCDR0. Executes the same five-step flow:
 *   1. MAELGCK0 → MaEligibilityService.isEligible()
 *   2. MAHCCVL0 → HccValidationService.validateHccCodes()
 *   3. MARAFCL0 → RafCalculationService.calculateRaf()
 *   4. MAENCBL0 → EncounterBuilderService.buildAndStageEncounters()
 *   5. MAEDPSUB0 → EdpsSubmissionService.submitToEdps()
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class EncounterDataOrchestrator {

    private final MaEligibilityService eligibilityService;
    private final HccValidationService hccValidationService;
    private final RafCalculationService rafCalculationService;
    private final EncounterBuilderService encounterBuilderService;
    private final EdpsSubmissionService edpsSubmissionService;

    /**
     * Processes a single member's encounter data end-to-end.
     * Corresponds to MAENCDR0 paragraph 2000-PROCESS.
     */
    @Transactional
    public EncounterProcessingResult processMember(String mbi,
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
     * Batch entry point — processes a list of members and returns an aggregate summary.
     * Corresponds to MAENCDR0 paragraph 2000-PROCESS loop.
     */
    @Transactional
    public EncounterBatchSummary processBatch(List<MemberEncounterRequest> requests) {
        List<EncounterProcessingResult> errors = new ArrayList<>();
        int eligible = 0, ineligible = 0, hccValid = 0, hccReject = 0,
                encountered = 0, submitted = 0, errorCount = 0;

        for (MemberEncounterRequest req : requests) {
            EncounterProcessingResult result =
                    processMember(req.mbi(), req.contractId(), req.paymentYear(), req.hccRecords());
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
