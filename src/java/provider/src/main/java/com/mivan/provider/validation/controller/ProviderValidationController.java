package com.mivan.provider.validation.controller;

import com.mivan.provider.validation.model.CredentialingStatus;
import com.mivan.provider.validation.model.ProviderMaster;
import com.mivan.provider.validation.model.ProviderSanctionLog;
import com.mivan.provider.validation.model.ProviderValidationRequest;
import com.mivan.provider.validation.model.ProviderValidationResponse;
import com.mivan.provider.validation.orchestrator.ProviderValidationOrchestrator;
import com.mivan.provider.validation.repository.ProviderMasterRepository;
import com.mivan.provider.validation.repository.ProviderSanctionLogRepository;
import com.mivan.provider.validation.service.CredentialingCheckService;
import com.mivan.provider.validation.service.ExclusionCheckService;
import com.mivan.provider.validation.service.ExclusionCheckService.ExclusionResult;
import com.mivan.provider.validation.service.NetworkVerificationService;
import com.mivan.provider.validation.service.NetworkVerificationService.NetworkVerificationResult;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.time.LocalDate;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * REST endpoints for MiCPS provider validation.
 *
 * <p>Exposes the {@code MPRVVLDR0} program tree over HTTP.</p>
 */
@RestController
@RequestMapping("/api/v1/provider")
@RequiredArgsConstructor
@Tag(name = "Provider Validation",
     description = "Provider NPI, credentialing, exclusion, and network checks "
                 + "— Java equivalent of the MPRVVLDR0 COBOL program tree")
public class ProviderValidationController {

    private final ProviderValidationOrchestrator orchestrator;
    private final CredentialingCheckService credentialingService;
    private final ExclusionCheckService exclusionService;
    private final NetworkVerificationService networkService;
    private final ProviderMasterRepository providerMasterRepository;
    private final ProviderSanctionLogRepository sanctionLogRepository;

    @Operation(summary = "Validate a provider",
            description = "Runs the full five-step validation sequence "
                        + "(NPI lookup, credentialing, exclusion, network, "
                        + "sanction logging).")
    @PostMapping("/validate")
    public ResponseEntity<ProviderValidationResponse> validate(
            @Valid @RequestBody ProviderValidationRequest request) {
        LocalDate dos = request.getDateOfService() == null
                ? LocalDate.now() : request.getDateOfService();
        return ResponseEntity.ok(
                orchestrator.validateProvider(request.getNpi(), dos));
    }

    @Operation(summary = "Get provider master record")
    @GetMapping("/{npi}")
    public ResponseEntity<ProviderMaster> getProvider(@PathVariable String npi) {
        return providerMasterRepository.findById(npi)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @Operation(summary = "Check provider credentialing status")
    @GetMapping("/{npi}/credentials")
    public ResponseEntity<CredentialingStatus> getCredentials(
            @PathVariable String npi,
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dos) {
        LocalDate effectiveDos = dos == null ? LocalDate.now() : dos;
        return ResponseEntity.ok(
                credentialingService.checkCredentials(npi, effectiveDos));
    }

    @Operation(summary = "Get provider network participation status")
    @GetMapping("/{npi}/network-status")
    public ResponseEntity<NetworkVerificationResult> getNetworkStatus(
            @PathVariable String npi,
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dos) {
        LocalDate effectiveDos = dos == null ? LocalDate.now() : dos;
        return ResponseEntity.ok(
                networkService.verifyNetwork(npi, effectiveDos));
    }

    @Operation(summary = "Check provider exclusion status",
            description = "Screens OIG LEIE, SAM, and state exclusion lists. "
                        + "Federal law prohibits payment to excluded providers.")
    @GetMapping("/exclusions/check/{npi}")
    public ResponseEntity<ExclusionResult> checkExclusions(
            @PathVariable String npi) {
        String taxId = providerMasterRepository.findById(npi)
                .map(ProviderMaster::getTaxId)
                .orElse(null);
        return ResponseEntity.ok(
                exclusionService.checkExclusions(npi, taxId));
    }

    @Operation(summary = "Get provider sanction / validation history")
    @GetMapping("/sanctions/{npi}")
    public ResponseEntity<List<ProviderSanctionLog>> getSanctions(
            @PathVariable String npi) {
        return ResponseEntity.ok(
                sanctionLogRepository.findByNpiOrderByLogTsDesc(npi));
    }
}
