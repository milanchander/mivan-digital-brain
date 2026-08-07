package com.mivan.micps.controller;
import com.mivan.micps.model.ClaimPayment;
import com.mivan.micps.repository.ClaimPaymentRepository;
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
    private final ClaimPaymentRepository repository;
    @PostMapping("/evaluate")
    @Operation(summary="Evaluate a claim for near-duplicate status")
    public ResponseEntity<EvaluationResult> evaluate(@RequestBody ClaimPayment claim) {
        return ResponseEntity.ok(service.evaluate(claim));
    }
    @PostMapping("/seed")
    @Operation(summary="Seed a paid claim into CLAIM_PAYMENT for testing")
    public ResponseEntity<ClaimPayment> seed(@RequestBody ClaimPayment claim) {
        return ResponseEntity.ok(repository.save(claim));
    }
}