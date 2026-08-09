package com.mivan.ma.controller;

import com.mivan.ma.model.*;
import com.mivan.ma.repository.MaEncounterStagingRepository;
import com.mivan.ma.repository.MaRafScoreRepository;
import com.mivan.ma.service.MaPostAdjudicationService;
import com.mivan.ma.service.MaPostAdjudicationService.MemberEncounterRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * REST entry points for MA post-adjudication CMS reporting. Invoked by MiFCT
 * (TriZetto Facets) after it has adjudicated a Medicare Advantage claim.
 */
@RestController
@RequestMapping("/api/v1/ma")
@RequiredArgsConstructor
@Tag(name = "MA Post-Adjudication Reporting",
     description = "Post-adjudication CMS reporting for Medicare Advantage claims adjudicated by MiFCT (TriZetto Facets)")
public class MaPostAdjudicationController {

    private final MaPostAdjudicationService postAdjudicationService;
    private final MaEncounterStagingRepository stagingRepository;
    private final MaRafScoreRepository rafScoreRepository;

    @PostMapping("/post-adjudication/process")
    @Operation(summary = "Run post-adjudication reporting for a single member",
               description = "After MiFCT adjudication: eligibility confirmation, HCC validation, RAF calculation, encounter staging, and EDPS submission")
    public ResponseEntity<EncounterProcessingResult> process(
            @RequestBody MemberEncounterRequest request) {
        EncounterProcessingResult result = postAdjudicationService.processPostAdjudication(
                request.mbi(), request.contractId(), request.paymentYear(), request.hccRecords());
        return ResponseEntity.ok(result);
    }

    @PostMapping("/post-adjudication/batch")
    @Operation(summary = "Run post-adjudication reporting for a batch of members",
               description = "Returns aggregate counters for the post-adjudication reporting run")
    public ResponseEntity<EncounterBatchSummary> batch(
            @RequestBody List<MemberEncounterRequest> requests) {
        return ResponseEntity.ok(postAdjudicationService.processBatch(requests));
    }

    @GetMapping("/raf-scores/{memberId}")
    @Operation(summary = "Get calculated RAF scores for a member",
               description = "Returns MA_RAF_SCORE records produced during post-adjudication RAF calculation")
    public ResponseEntity<List<MaRafScore>> getRafScores(@PathVariable String memberId) {
        return ResponseEntity.ok(rafScoreRepository.findByMbi(memberId));
    }

    @GetMapping("/encounter-staging")
    @Operation(summary = "List staged encounters",
               description = "Returns encounter records staged for CMS EDPS submission")
    public ResponseEntity<List<MaEncounterStaging>> getEncounterStaging() {
        return ResponseEntity.ok(stagingRepository.findAll());
    }
}
