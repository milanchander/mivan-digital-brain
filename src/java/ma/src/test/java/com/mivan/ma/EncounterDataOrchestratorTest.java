package com.mivan.ma;

import com.mivan.ma.model.*;
import com.mivan.ma.service.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class EncounterDataOrchestratorTest {

    @Mock MaEligibilityService eligibilityService;
    @Mock HccValidationService hccValidationService;
    @Mock RafCalculationService rafCalculationService;
    @Mock EncounterBuilderService encounterBuilderService;
    @Mock EdpsSubmissionService edpsSubmissionService;

    @InjectMocks EncounterDataOrchestrator orchestrator;

    private MaEnrollment enrollment;
    private MaHccRecord hccRecord;
    private MaRafScore rafScore;
    private MaEncounterStaging staged;

    @BeforeEach
    void setUp() {
        enrollment = new MaEnrollment();
        enrollment.setMbi("1EG4TE5MK72");
        enrollment.setHicn("123456789A");
        enrollment.setContractId("H1234");
        enrollment.setPlanId("001");
        enrollment.setEffDate(LocalDate.of(2026, 1, 1));
        enrollment.setStatusCd("AC");

        hccRecord = new MaHccRecord();
        hccRecord.setMbi("1EG4TE5MK72");
        hccRecord.setIcd10Code("E1140");
        hccRecord.setHccCode("0019");
        hccRecord.setRafCoefficient(new BigDecimal("0.302000"));
        hccRecord.setValidationStatus("VA");
        hccRecord.setDosFrom(LocalDate.of(2026, 3, 1));
        hccRecord.setDosThru(LocalDate.of(2026, 3, 1));

        rafScore = new MaRafScore();
        rafScore.setMbi("1EG4TE5MK72");
        rafScore.setTotalRaf(new BigDecimal("0.689000"));

        staged = new MaEncounterStaging();
        staged.setEncounterId("H1234001ABCD12345678");
        staged.setMbi("1EG4TE5MK72");
        staged.setSubmissionStatus("SU");
        staged.setSubmitDate(LocalDate.now());
    }

    @Test
    void processMember_happyPath_returnsSuccess() {
        when(eligibilityService.getEnrollment("1EG4TE5MK72", "H1234"))
                .thenReturn(Optional.of(enrollment));
        when(eligibilityService.isEligible(eq("1EG4TE5MK72"), eq("H1234"), any()))
                .thenReturn(true);
        when(hccValidationService.validateHccCodes(any(), any(), any()))
                .thenReturn(List.of(hccRecord));
        when(rafCalculationService.calculateRaf(any(), any(), any()))
                .thenReturn(rafScore);
        when(encounterBuilderService.buildAndStageEncounters(any(), any(), any()))
                .thenReturn(List.of(staged));
        when(edpsSubmissionService.submitToEdps(any()))
                .thenReturn(List.of(staged));

        EncounterProcessingResult result = orchestrator.processMember(
                "1EG4TE5MK72", "H1234", "2026", List.of(hccRecord));

        assertThat(result.isEligible()).isTrue();
        assertThat(result.isHccValid()).isTrue();
        assertThat(result.isSuccess()).isTrue();
        assertThat(result.getEncounterId()).isEqualTo("H1234001ABCD12345678");
    }

    @Test
    void processMember_ineligible_returnsEligFail() {
        when(eligibilityService.getEnrollment(any(), any())).thenReturn(Optional.empty());

        EncounterProcessingResult result = orchestrator.processMember(
                "1EG4TE5MK72", "H1234", "2026", List.of(hccRecord));

        assertThat(result.isEligible()).isFalse();
        assertThat(result.getErrorCode()).isEqualTo("ELIG");
    }

    @Test
    void processMember_noValidHcc_returnsHccFail() {
        when(eligibilityService.getEnrollment(any(), any())).thenReturn(Optional.of(enrollment));
        when(eligibilityService.isEligible(any(), any(), any())).thenReturn(true);
        MaHccRecord invalid = new MaHccRecord();
        invalid.setValidationStatus("IN");
        when(hccValidationService.validateHccCodes(any(), any(), any()))
                .thenReturn(List.of(invalid));

        EncounterProcessingResult result = orchestrator.processMember(
                "1EG4TE5MK72", "H1234", "2026", List.of(hccRecord));

        assertThat(result.isEligible()).isTrue();
        assertThat(result.isHccValid()).isFalse();
        assertThat(result.getErrorCode()).isEqualTo("NOHC");
    }

    @Test
    void processBatch_aggregatesCountsCorrectly() {
        when(eligibilityService.getEnrollment(any(), any())).thenReturn(Optional.of(enrollment));
        when(eligibilityService.isEligible(any(), any(), any())).thenReturn(true);
        when(hccValidationService.validateHccCodes(any(), any(), any()))
                .thenReturn(List.of(hccRecord));
        when(rafCalculationService.calculateRaf(any(), any(), any())).thenReturn(rafScore);
        when(encounterBuilderService.buildAndStageEncounters(any(), any(), any()))
                .thenReturn(List.of(staged));
        when(edpsSubmissionService.submitToEdps(any())).thenReturn(List.of(staged));

        var req = new EncounterDataOrchestrator.MemberEncounterRequest(
                "1EG4TE5MK72", "H1234", "2026", List.of(hccRecord));
        EncounterBatchSummary summary = orchestrator.processBatch(List.of(req, req));

        assertThat(summary.getInputCount()).isEqualTo(2);
        assertThat(summary.getEligibleCount()).isEqualTo(2);
        assertThat(summary.getSubmitCount()).isEqualTo(2);
        assertThat(summary.getErrorCount()).isEqualTo(0);
        assertThat(summary.getReturnCode()).isEqualTo(0);
    }
}
