package com.mivan.ma.controller;

import com.mivan.ma.model.*;
import com.mivan.ma.repository.MaEncounterStagingRepository;
import com.mivan.ma.service.EdpsSubmissionService;
import com.mivan.ma.service.EncounterDataOrchestrator;
import com.mivan.ma.service.EncounterDataOrchestrator.MemberEncounterRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/ma/encounters")
@RequiredArgsConstructor
@Tag(name = "MA Encounter Processing", description = "Medicare Advantage encounter data pipeline — Java equivalent of MAENCDR0")
public class EncounterDataController {

    private final EncounterDataOrchestrator orchestrator;
    private final EdpsSubmissionService edpsSubmissionService;
    private final MaEncounterStagingRepository stagingRepository;

    @PostMapping("/process")
    @Operation(summary = "Process a single member's encounter data",
               description = "Runs eligibility check, HCC validation, RAF calculation, encounter build, and EDPS submission")
    public ResponseEntity<EncounterProcessingResult> processMember(
            @RequestBody MemberEncounterRequest request) {
        EncounterProcessingResult result = orchestrator.processMember(
                request.mbi(), request.contractId(), request.paymentYear(), request.hccRecords());
        return ResponseEntity.ok(result);
    }

    @PostMapping("/batch")
    @Operation(summary = "Process a batch of members",
               description = "Equivalent to the MAENCDR0 JCL batch job — returns aggregate counters matching the COBOL report")
    public ResponseEntity<EncounterBatchSummary> processBatch(
            @RequestBody List<MemberEncounterRequest> requests) {
        return ResponseEntity.ok(orchestrator.processBatch(requests));
    }

    @GetMapping("/staging/{contractId}/pending")
    @Operation(summary = "List pending encounters for a contract",
               description = "Returns encounters with SUBMISSION_STATUS = PE (pending EDPS submission)")
    public ResponseEntity<List<MaEncounterStaging>> getPendingEncounters(
            @PathVariable String contractId) {
        return ResponseEntity.ok(
                stagingRepository.findByContractIdAndSubmissionStatus(contractId, "PE"));
    }

    @PostMapping("/staging/{contractId}/resubmit")
    @Operation(summary = "Re-submit pending encounters to EDPS",
               description = "Retries submission for all PE-status records; mirrors MAEDPSUB0 retry logic")
    public ResponseEntity<List<MaEncounterStaging>> resubmitPending(
            @PathVariable String contractId) {
        return ResponseEntity.ok(edpsSubmissionService.resubmitPending(contractId));
    }
}
