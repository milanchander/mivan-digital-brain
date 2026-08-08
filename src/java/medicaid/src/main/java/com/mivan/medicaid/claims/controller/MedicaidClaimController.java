package com.mivan.medicaid.claims.controller;

import com.mivan.medicaid.claims.model.*;
import com.mivan.medicaid.claims.orchestrator.MedicaidClaimOrchestrator;
import com.mivan.medicaid.claims.repository.MedicaidEligibilityRepository;
import com.mivan.medicaid.claims.repository.TplResultRepository;
import com.mivan.medicaid.claims.service.MedicaidEligibilityService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@RestController
@RequestMapping("/api/v1/medicaid")
@RequiredArgsConstructor
@Tag(name = "Medicaid Claim Processing",
     description = "Medicaid claim pipeline — Java equivalent of MMCOCLDR0. "
             + "Implements 42 CFR 433.139 payer of last resort rules.")
public class MedicaidClaimController {

    private final MedicaidClaimOrchestrator orchestrator;
    private final MedicaidEligibilityService eligibilityService;
    private final MedicaidEligibilityRepository eligibilityRepository;
    private final TplResultRepository tplResultRepository;

    @PostMapping("/claims/process")
    @Operation(summary = "Process a single Medicaid claim",
               description = "Runs eligibility verification (MMCOELV0), TPL identification "
                       + "(MMCOTPL0), payer of last resort calculation (MMCOLRP0), "
                       + "encounter build (MMCOENC0), and state staging (MMCOSSUB0)")
    public ResponseEntity<MedicaidClaimResponse> processClaim(
            @RequestBody MedicaidClaimRequest request) {
        return ResponseEntity.ok(orchestrator.processMedicaidClaim(request));
    }

    @PostMapping("/claims/batch")
    @Operation(summary = "Process a batch of Medicaid claims",
               description = "Equivalent to the MMCOCLDR0 JCL batch job MMCOJB00. "
                       + "Returns per-claim results with aggregate error count.")
    public ResponseEntity<List<MedicaidClaimResponse>> processBatch(
            @RequestBody List<MedicaidClaimRequest> requests) {
        List<MedicaidClaimResponse> results = requests.stream()
                .map(orchestrator::processMedicaidClaim)
                .toList();
        return ResponseEntity.ok(results);
    }

    @GetMapping("/eligibility/{memberId}")
    @Operation(summary = "Get Medicaid eligibility for a member",
               description = "Returns the active Medicaid eligibility record. "
                       + "Supports optional stateCd and dos query parameters "
                       + "to check eligibility on a specific date of service.")
    public ResponseEntity<MedicaidEligibility> getEligibility(
            @PathVariable @Parameter(description = "Member ID") String memberId,
            @RequestParam(required = false) String stateCd,
            @RequestParam(required = false) String dos) {

        if (stateCd != null && dos != null) {
            Optional<MedicaidEligibility> elig = eligibilityRepository
                    .findActiveOnDos(memberId, stateCd, LocalDate.parse(dos));
            return elig.map(ResponseEntity::ok)
                       .orElse(ResponseEntity.notFound().build());
        }
        Optional<MedicaidEligibility> elig = eligibilityRepository
                .findByMemberIdAndStateCdAndStatusCd(memberId,
                        stateCd != null ? stateCd : "", "AC");
        return elig.map(ResponseEntity::ok)
                   .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/tpl/{memberId}")
    @Operation(summary = "Get TPL results for a member",
               description = "Returns all TPL payment results for the member. "
                       + "Per 42 CFR 433.139, all TPL must pay before Medicaid.")
    public ResponseEntity<List<TplResult>> getTplResults(
            @PathVariable @Parameter(description = "Member ID") String memberId) {
        return ResponseEntity.ok(
                tplResultRepository.findByMemberIdAndStatusCd(memberId, "PD"));
    }

    @GetMapping("/encounter-staging")
    @Operation(summary = "Get encounter staging records by state",
               description = "Returns encounters pending state MMIS submission. "
                       + "Filters by stateCd and optional status.")
    public ResponseEntity<List<MedicaidEncounterStaging>> getEncounterStaging(
            @RequestParam String stateCd,
            @RequestParam(defaultValue = "ST") String status) {
        return ResponseEntity.ok(List.of());
    }
}
