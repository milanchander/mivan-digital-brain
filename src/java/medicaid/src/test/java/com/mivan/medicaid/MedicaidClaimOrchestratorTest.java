package com.mivan.medicaid;

import com.mivan.medicaid.claims.model.*;
import com.mivan.medicaid.claims.orchestrator.MedicaidClaimOrchestrator;
import com.mivan.medicaid.claims.service.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class MedicaidClaimOrchestratorTest {

    @Mock MedicaidEligibilityService eligibilityService;
    @Mock ThirdPartyLiabilityService tplService;
    @Mock PayerOfLastResortService lastResortService;
    @Mock EncounterBuildService encounterBuildService;
    @Mock StateSubmissionService stateSubmissionService;

    @InjectMocks MedicaidClaimOrchestrator orchestrator;

    private MedicaidClaimRequest request;
    private MedicaidEligibility eligibility;
    private TplResult tplResult;
    private MedicaidLiability liability;
    private MedicaidEncounterStaging staging;

    @BeforeEach
    void setUp() {
        request = new MedicaidClaimRequest();
        request.setClaimId("CLM20260808001");
        request.setMemberId("MC123456789ABCD");
        request.setStateCd("OH");
        request.setDos(LocalDate.of(2026, 6, 15));

        eligibility = new MedicaidEligibility();
        eligibility.setMemberId("MC123456789ABCD");
        eligibility.setStateCd("OH");
        eligibility.setMcoId("MCO0000001");
        eligibility.setStatusCd("AC");
        eligibility.setEligFromDt(LocalDate.of(2026, 1, 1));
        eligibility.setDualEligInd("N");
        eligibility.setChipInd("N");
        eligibility.setEpsdtInd("N");
        eligibility.setSpendDownInd("N");

        tplResult = TplResult.builder()
                .claimId("CLM20260808001")
                .memberId("MC123456789ABCD")
                .payerId("PAYER001")
                .paidAmt(new BigDecimal("45.00"))
                .statusCd("PD")
                .build();

        liability = MedicaidLiability.builder()
                .claimId("CLM20260808001")
                .memberId("MC123456789ABCD")
                .stateCd("OH")
                .billedAmt(new BigDecimal("100.00"))
                .tplPaidAmt(new BigDecimal("45.00"))
                .memberRespAmt(new BigDecimal("3.00"))
                .medicaidAmt(new BigDecimal("52.00"))
                .statusCd("CM")
                .build();

        staging = MedicaidEncounterStaging.builder()
                .claimId("CLM20260808001")
                .memberId("MC123456789ABCD")
                .stateCd("OH")
                .mcoId("MCO0000001")
                .provNpi("1234567890")
                .dosFrom(LocalDate.of(2026, 6, 15))
                .status("ST")
                .build();
    }

    @Test
    void processClaim_happyPath_returnsSuccess() {
        when(eligibilityService.verifyEligibility(any(), any(), any()))
                .thenReturn(MedicaidEligibilityService.MedicaidEligibilityStatus.ELIGIBLE);
        when(eligibilityService.getEligibility(any(), any()))
                .thenReturn(Optional.of(eligibility));
        when(tplService.identifyTpl(any(), any(), any()))
                .thenReturn(Optional.of(tplResult));
        when(lastResortService.calculateMedicaidLiability(any(), any(), any(), any()))
                .thenReturn(liability);
        when(encounterBuildService.buildEncounter(
                any(), any(), any(), any(), any(), any(), any(), any()))
                .thenReturn(staging);
        when(stateSubmissionService.stageForSubmission(any()))
                .thenReturn(true);

        MedicaidClaimResponse resp = orchestrator.processMedicaidClaim(request);

        assertThat(resp.isEligible()).isTrue();
        assertThat(resp.isTplFound()).isTrue();
        assertThat(resp.getTplPaidAmt()).isEqualByComparingTo("45.00");
        assertThat(resp.getMedicaidLiabilityAmt()).isEqualByComparingTo("52.00");
        assertThat(resp.isStagedForSubmission()).isTrue();
        assertThat(resp.isSuccess()).isTrue();
    }

    @Test
    void processClaim_ineligible_returnsEligError() {
        when(eligibilityService.verifyEligibility(any(), any(), any()))
                .thenReturn(MedicaidEligibilityService.MedicaidEligibilityStatus.INELIGIBLE);

        MedicaidClaimResponse resp = orchestrator.processMedicaidClaim(request);

        assertThat(resp.isEligible()).isFalse();
        assertThat(resp.getErrorCode()).isEqualTo("ELIG");
        assertThat(resp.isStagedForSubmission()).isFalse();
        verifyNoInteractions(tplService, lastResortService, encounterBuildService);
    }

    @Test
    void processClaim_noTpl_medicaidPaysFullAmount() {
        when(eligibilityService.verifyEligibility(any(), any(), any()))
                .thenReturn(MedicaidEligibilityService.MedicaidEligibilityStatus.ELIGIBLE);
        when(eligibilityService.getEligibility(any(), any()))
                .thenReturn(Optional.of(eligibility));
        when(tplService.identifyTpl(any(), any(), any()))
                .thenReturn(Optional.empty());

        MedicaidLiability fullLiability = MedicaidLiability.builder()
                .claimId("CLM20260808001").memberId("MC123456789ABCD")
                .stateCd("OH").billedAmt(new BigDecimal("100.00"))
                .tplPaidAmt(BigDecimal.ZERO).memberRespAmt(new BigDecimal("3.00"))
                .medicaidAmt(new BigDecimal("97.00")).statusCd("CM").build();

        when(lastResortService.calculateMedicaidLiability(any(), any(), isNull(), any()))
                .thenReturn(fullLiability);
        when(encounterBuildService.buildEncounter(
                any(), any(), any(), any(), any(), any(), any(), any()))
                .thenReturn(staging);
        when(stateSubmissionService.stageForSubmission(any())).thenReturn(true);

        MedicaidClaimResponse resp = orchestrator.processMedicaidClaim(request);

        assertThat(resp.isTplFound()).isFalse();
        assertThat(resp.getMedicaidLiabilityAmt()).isEqualByComparingTo("97.00");
    }

    @Test
    void processClaim_stagingFails_notStaged() {
        when(eligibilityService.verifyEligibility(any(), any(), any()))
                .thenReturn(MedicaidEligibilityService.MedicaidEligibilityStatus.ELIGIBLE);
        when(eligibilityService.getEligibility(any(), any()))
                .thenReturn(Optional.of(eligibility));
        when(tplService.identifyTpl(any(), any(), any()))
                .thenReturn(Optional.empty());
        when(lastResortService.calculateMedicaidLiability(any(), any(), any(), any()))
                .thenReturn(liability);
        when(encounterBuildService.buildEncounter(
                any(), any(), any(), any(), any(), any(), any(), any()))
                .thenReturn(staging);
        when(stateSubmissionService.stageForSubmission(any())).thenReturn(false);

        MedicaidClaimResponse resp = orchestrator.processMedicaidClaim(request);

        assertThat(resp.isStagedForSubmission()).isFalse();
        assertThat(resp.isSuccess()).isFalse();
    }
}
