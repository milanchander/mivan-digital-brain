package com.mivan.micps.controller;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.mivan.micps.model.ClaimPayment;
import com.mivan.micps.model.MatchType;
import com.mivan.micps.repository.ClaimPaymentRepository;
import com.mivan.micps.service.DuplicateClaimDetectionService;
import com.mivan.micps.service.DuplicateClaimDetectionService.EvaluationResult;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import java.math.BigDecimal;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
@WebMvcTest(DuplicateClaimController.class)
class DuplicateClaimControllerTest {
    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;
    @MockBean DuplicateClaimDetectionService service;
    @MockBean ClaimPaymentRepository repository;
    @Test void evaluate_nearDup() throws Exception {
        when(service.evaluate(any())).thenReturn(EvaluationResult.nearDup("CLM-NEW-002","CLM-ORIG-001",MatchType.AMT_VAR));
        mockMvc.perform(post("/api/v1/claims/evaluate").contentType(MediaType.APPLICATION_JSON)
            .content(objectMapper.writeValueAsString(claim())))
            .andExpect(status().isOk()).andExpect(jsonPath("$.outcome").value("NEAR_DUP"));
    }
    @Test void evaluate_clean() throws Exception {
        when(service.evaluate(any())).thenReturn(EvaluationResult.clean("CLM-NEW-002"));
        mockMvc.perform(post("/api/v1/claims/evaluate").contentType(MediaType.APPLICATION_JSON)
            .content(objectMapper.writeValueAsString(claim())))
            .andExpect(status().isOk()).andExpect(jsonPath("$.outcome").value("CLEAN"));
    }
    @Test void evaluate_skipped() throws Exception {
        when(service.evaluate(any())).thenReturn(EvaluationResult.skipped("CLM-NEW-002"));
        mockMvc.perform(post("/api/v1/claims/evaluate").contentType(MediaType.APPLICATION_JSON)
            .content(objectMapper.writeValueAsString(claim())))
            .andExpect(status().isOk()).andExpect(jsonPath("$.outcome").value("SKIPPED"));
    }
    @Test void evaluate_emptyBody_ok() throws Exception {
        when(service.evaluate(any())).thenReturn(EvaluationResult.clean(null));
        mockMvc.perform(post("/api/v1/claims/evaluate").contentType(MediaType.APPLICATION_JSON).content("{}"))
            .andExpect(status().isOk());
    }
    @Test void seed_returnsSavedClaim() throws Exception {
        ClaimPayment c = claim();
        when(repository.save(any())).thenReturn(c);
        mockMvc.perform(post("/api/v1/claims/seed").contentType(MediaType.APPLICATION_JSON)
            .content(objectMapper.writeValueAsString(c)))
            .andExpect(status().isOk()).andExpect(jsonPath("$.claimId").value("CLM-NEW-002"));
    }
    private ClaimPayment claim() {
        return ClaimPayment.builder().claimId("CLM-NEW-002").memberId("MBR-12345")
            .provNpi("1234567890").dosFrom(20260720).cptCd("99213")
            .chargeAmt(new BigDecimal("327.00")).paymentStatusCd("PD").build();
    }
}