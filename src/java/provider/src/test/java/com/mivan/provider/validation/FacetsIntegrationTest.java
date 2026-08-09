package com.mivan.provider.validation;

import com.mivan.provider.validation.model.CredentialingStatus;
import com.mivan.provider.validation.model.FacetsValidationRequest;
import com.mivan.provider.validation.model.FacetsValidationResponse;
import com.mivan.provider.validation.model.NetworkStatus;
import com.mivan.provider.validation.model.ProviderMaster;
import com.mivan.provider.validation.model.ProviderValidationStatus;
import com.mivan.provider.validation.orchestrator.ProviderValidationOrchestrator;
import com.mivan.provider.validation.service.CredentialingCheckService;
import com.mivan.provider.validation.service.ExclusionCheckService;
import com.mivan.provider.validation.service.ExclusionCheckService.ExclusionResult;
import com.mivan.provider.validation.service.NetworkVerificationService;
import com.mivan.provider.validation.service.NetworkVerificationService.NetworkVerificationResult;
import com.mivan.provider.validation.service.ProviderNpiLookupService;
import com.mivan.provider.validation.service.SanctionLogService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

/**
 * Tests for the Facets Option A REST integration ({@code validateProviderForFacets}).
 * Provider validation is LOB-agnostic — MiFCT calls it after routing MA/Medicaid claims.
 */
@ExtendWith(MockitoExtension.class)
class FacetsIntegrationTest {

    private static final String NPI = "1234567893";
    private static final String TAX_ID = "123456789";

    @Mock ProviderNpiLookupService npiLookupService;
    @Mock CredentialingCheckService credentialingService;
    @Mock ExclusionCheckService exclusionService;
    @Mock NetworkVerificationService networkService;
    @Mock SanctionLogService sanctionLogService;

    @InjectMocks ProviderValidationOrchestrator orchestrator;

    private ProviderMaster provider;

    @BeforeEach
    void setUp() {
        provider = ProviderMaster.builder()
                .npi(NPI)
                .taxId(TAX_ID)
                .statusCd("AC")
                .build();
    }

    private FacetsValidationRequest request(String lobCode) {
        return FacetsValidationRequest.builder()
                .facetsTransactionId("FCT-20260809-000123")
                .npi(NPI)
                .taxId(TAX_ID)
                .dateOfService(LocalDate.of(2026, 8, 1))
                .lobCode(lobCode)
                .claimId("CLM20260809001")
                .planId("H1234-001")
                .build();
    }

    @Test
    void testFacetsValidation_ValidProvider_ReturnsSuccess() {
        // Validates Facets Option A REST integration
        when(npiLookupService.lookupProvider(eq(NPI), any())).thenReturn(Optional.of(provider));
        when(credentialingService.checkCredentials(eq(NPI), any()))
                .thenReturn(CredentialingStatus.CREDENTIALED);
        when(exclusionService.checkExclusions(eq(NPI), any()))
                .thenReturn(new ExclusionResult(false, null, null));
        when(networkService.verifyNetwork(eq(NPI), any()))
                .thenReturn(new NetworkVerificationResult(NetworkStatus.INN, "T1", "FS-COMM-01", true));

        FacetsValidationResponse resp = orchestrator.validateProviderForFacets(request("MA"));

        assertThat(resp.getFacetsTransactionId()).isEqualTo("FCT-20260809-000123");
        assertThat(resp.getStatus()).isEqualTo(ProviderValidationStatus.VALID);
        assertThat(resp.isCredentialingValid()).isTrue();
        assertThat(resp.isExcluded()).isFalse();
        assertThat(resp.getNetworkStatus()).isEqualTo(NetworkStatus.INN);
        assertThat(resp.getTierCode()).isEqualTo("T1");
        assertThat(resp.getValidatedAt()).isNotNull();
    }

    @Test
    void testFacetsValidation_ExcludedProvider_ReturnsDeny() {
        // Validates Facets Option A REST integration
        when(npiLookupService.lookupProvider(eq(NPI), any())).thenReturn(Optional.of(provider));
        when(credentialingService.checkCredentials(eq(NPI), any()))
                .thenReturn(CredentialingStatus.CREDENTIALED);
        when(exclusionService.checkExclusions(eq(NPI), any()))
                .thenReturn(new ExclusionResult(true, "OIG-LEIE", "EXCLUDED - OIG LEIE"));

        FacetsValidationResponse resp = orchestrator.validateProviderForFacets(request("MC"));

        assertThat(resp.getStatus()).isEqualTo(ProviderValidationStatus.EXCLUDED);
        assertThat(resp.isExcluded()).isTrue();
        assertThat(resp.getExclusionSource()).isEqualTo("OIG-LEIE");
        assertThat(resp.getDenyReason()).isEqualTo("EXCLUDED - OIG LEIE");
    }

    @Test
    void testFacetsValidation_ExpiredCredentials_ReturnsDeny() {
        // Validates Facets Option A REST integration
        when(npiLookupService.lookupProvider(eq(NPI), any())).thenReturn(Optional.of(provider));
        when(credentialingService.checkCredentials(eq(NPI), any()))
                .thenReturn(CredentialingStatus.EXPIRED);
        when(exclusionService.checkExclusions(eq(NPI), any()))
                .thenReturn(new ExclusionResult(false, null, null));
        when(networkService.verifyNetwork(eq(NPI), any()))
                .thenReturn(new NetworkVerificationResult(NetworkStatus.INN, "T1", "FS-COMM-01", true));

        FacetsValidationResponse resp = orchestrator.validateProviderForFacets(request("MA"));

        assertThat(resp.getStatus()).isEqualTo(ProviderValidationStatus.NOT_CREDENTIALED);
        assertThat(resp.isCredentialingValid()).isFalse();
        assertThat(resp.getDenyReason()).contains("CREDENTIALING FAILED");
    }

    @Test
    void testFacetsValidation_OutOfNetwork_ReturnsOON() {
        // Validates Facets Option A REST integration
        when(npiLookupService.lookupProvider(eq(NPI), any())).thenReturn(Optional.of(provider));
        when(credentialingService.checkCredentials(eq(NPI), any()))
                .thenReturn(CredentialingStatus.CREDENTIALED);
        when(exclusionService.checkExclusions(eq(NPI), any()))
                .thenReturn(new ExclusionResult(false, null, null));
        when(networkService.verifyNetwork(eq(NPI), any()))
                .thenReturn(new NetworkVerificationResult(NetworkStatus.OON, null, null, false));

        FacetsValidationResponse resp = orchestrator.validateProviderForFacets(request("MC"));

        assertThat(resp.getNetworkStatus()).isEqualTo(NetworkStatus.OON);
        assertThat(resp.getStatus()).isEqualTo(ProviderValidationStatus.VALID);
    }
}
