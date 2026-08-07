package com.mivan.micps.controller;
import com.mivan.micps.model.ClaimPayment;
import com.mivan.micps.service.DuplicateClaimDetectionService;
import com.mivan.micps.service.DuplicateClaimDetectionService.EvaluationResult;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1/claims") @RequiredArgsConstructor
@Tag(name="Duplicate Detection",description="MICPS-4471 near-duplicate claim detection")
public class DuplicateClaimController {
    private final DuplicateClaimDetectionService service;
    @PostMapping("/evaluate")
    @Operation(summary="Evaluate a claim for near-duplicate status")
    public ResponseEntity<EvaluationResult> evaluate(@RequestBody ClaimPayment claim) {
        return ResponseEntity.ok(service.evaluate(claim));
    }
}