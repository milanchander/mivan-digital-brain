package com.mivan.micps.service;
import com.mivan.micps.model.ClaimPayment;
import com.mivan.micps.model.MatchType;
import com.mivan.micps.repository.ClaimPaymentRepository;
import com.mivan.micps.repository.NearDupQueueRepository;
import com.mivan.micps.service.DuplicateClaimDetectionService.EvaluationResult;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import java.math.BigDecimal;
import java.util.List;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;
@ExtendWith(MockitoExtension.class)
class DuplicateClaimDetectionServiceTest {
    @Mock ClaimPaymentRepository claimPaymentRepository;
    @Mock NearDupQueueRepository nearDupQueueRepository;
    @InjectMocks DuplicateClaimDetectionService service;
    private ClaimPayment paidClaim;
    @BeforeEach void setUp() {
        paidClaim = ClaimPayment.builder().claimId("CLM-ORIG-001").memberId("MBR-12345")
            .provNpi("1234567890").dosFrom(20260720).dosTo(20260720).cptCd("99213")
            .modifier1("  ").modifier2("  ").chargeAmt(new BigDecimal("300.00"))
            .paidAmt(new BigDecimal("240.00")).paymentStatusCd("PD").build();
    }
    @Test @DisplayName("TC-01: ED flag skips evaluation")
    void tc01() {
        assertThat(service.evaluate(builder().paymentStatusCd("ED").build()).outcome())
            .isEqualTo(EvaluationResult.Outcome.SKIPPED);
    }
    @Test @DisplayName("TC-02: 9% charge variance -> AMT_VAR")
    void tc02() {
        when(claimPaymentRepository.findPaidCandidates(anyString(),anyString(),anyString(),anyInt(),anyInt(),anyString())).thenReturn(List.of(paidClaim));
        when(nearDupQueueRepository.save(any())).thenAnswer(i -> i.getArgument(0));
        EvaluationResult r = service.evaluate(builder().chargeAmt(new BigDecimal("327.00")).build());
        assertThat(r.outcome()).isEqualTo(EvaluationResult.Outcome.NEAR_DUP);
        assertThat(r.matchType()).isEqualTo(MatchType.AMT_VAR);
    }
    @Test @DisplayName("TC-03: DOS +1 day -> DATE_DRIFT")
    void tc03() {
        when(claimPaymentRepository.findPaidCandidates(anyString(),anyString(),anyString(),anyInt(),anyInt(),anyString())).thenReturn(List.of(paidClaim));
        when(nearDupQueueRepository.save(any())).thenAnswer(i -> i.getArgument(0));
        EvaluationResult r = service.evaluate(builder().dosFrom(20260721).dosTo(20260721).build());
        assertThat(r.outcome()).isEqualTo(EvaluationResult.Outcome.NEAR_DUP);
        assertThat(r.matchType()).isEqualTo(MatchType.DATE_DRIFT);
    }
    @Test @DisplayName("TC-04: Modifier 59 vs blank -> MODIFIER")
    void tc04() {
        when(claimPaymentRepository.findPaidCandidates(anyString(),anyString(),anyString(),anyInt(),anyInt(),anyString())).thenReturn(List.of(paidClaim));
        when(nearDupQueueRepository.save(any())).thenAnswer(i -> i.getArgument(0));
        EvaluationResult r = service.evaluate(builder().modifier1("59").build());
        assertThat(r.outcome()).isEqualTo(EvaluationResult.Outcome.NEAR_DUP);
        assertThat(r.matchType()).isEqualTo(MatchType.MODIFIER);
    }
    @Test @DisplayName("TC-05: 15% charge variance -> CLEAN")
    void tc05() {
        when(claimPaymentRepository.findPaidCandidates(anyString(),anyString(),anyString(),anyInt(),anyInt(),anyString())).thenReturn(List.of(paidClaim));
        assertThat(service.evaluate(builder().chargeAmt(new BigDecimal("345.00")).build()).outcome())
            .isEqualTo(EvaluationResult.Outcome.CLEAN);
    }
    @Test @DisplayName("TC-06: DOS +2 days -> CLEAN")
    void tc06() {
        when(claimPaymentRepository.findPaidCandidates(anyString(),anyString(),anyString(),anyInt(),anyInt(),anyString())).thenReturn(List.of());
        assertThat(service.evaluate(builder().dosFrom(20260722).dosTo(20260722).build()).outcome())
            .isEqualTo(EvaluationResult.Outcome.CLEAN);
    }
    @Test void chargeVariancePct_9pct() {
        assertThat(service.chargeVariancePct(new BigDecimal("327.00"),new BigDecimal("300.00"))).isEqualByComparingTo(new BigDecimal("9.00"));
    }
    @Test void chargeVariancePct_15pct() {
        assertThat(service.chargeVariancePct(new BigDecimal("345.00"),new BigDecimal("300.00"))).isEqualByComparingTo(new BigDecimal("15.00"));
    }
    @Test void chargeVariancePct_zeroPaid() {
        assertThat(service.chargeVariancePct(new BigDecimal("100.00"),BigDecimal.ZERO)).isEqualByComparingTo(BigDecimal.ZERO);
    }
    private ClaimPayment.ClaimPaymentBuilder builder() {
        return ClaimPayment.builder().claimId("CLM-NEW-002").memberId("MBR-12345")
            .provNpi("1234567890").dosFrom(20260720).dosTo(20260720).cptCd("99213")
            .modifier1("  ").modifier2("  ").chargeAmt(new BigDecimal("300.00")).paymentStatusCd("PD");
    }
}