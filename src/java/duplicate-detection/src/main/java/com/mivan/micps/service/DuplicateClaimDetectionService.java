package com.mivan.micps.service;
import com.mivan.micps.model.ClaimPayment;
import com.mivan.micps.model.MatchType;
import com.mivan.micps.model.NearDupQueue;
import com.mivan.micps.repository.ClaimPaymentRepository;
import com.mivan.micps.repository.NearDupQueueRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Optional;
@Service @RequiredArgsConstructor @Slf4j
public class DuplicateClaimDetectionService {
    static final BigDecimal CHARGE_TOLERANCE_PCT = new BigDecimal("0.10");
    static final int DOS_TOLERANCE_DAYS = 1;
    private final ClaimPaymentRepository claimPaymentRepository;
    private final NearDupQueueRepository nearDupQueueRepository;
    @Transactional
    public EvaluationResult evaluate(ClaimPayment inbound) {
        if ("ED".equals(inbound.getPaymentStatusCd()))
            return EvaluationResult.skipped(inbound.getClaimId());
        int dosLow = inbound.getDosFrom() - 1, dosHigh = inbound.getDosFrom() + 1;
        List<ClaimPayment> candidates = claimPaymentRepository.findPaidCandidates(
            inbound.getMemberId(), inbound.getProvNpi(), inbound.getCptCd(),
            dosLow, dosHigh, inbound.getClaimId());
        for (ClaimPayment paid : candidates) {
            Optional<NearDupQueue> result = evaluateCandidate(inbound, paid);
            if (result.isPresent()) {
                NearDupQueue queued = nearDupQueueRepository.save(result.get());
                log.info("Near-dup detected: {} vs {} type={}", inbound.getClaimId(), paid.getClaimId(), queued.getNdupMatchType());
                return EvaluationResult.nearDup(inbound.getClaimId(), paid.getClaimId(), queued.getNdupMatchType());
            }
        }
        return EvaluationResult.clean(inbound.getClaimId());
    }
    Optional<NearDupQueue> evaluateCandidate(ClaimPayment inbound, ClaimPayment paid) {
        if (isExactDuplicate(inbound, paid)) return Optional.empty();
        BigDecimal variancePct = chargeVariancePct(inbound.getChargeAmt(), paid.getChargeAmt());
        if (variancePct.compareTo(new BigDecimal("10.00")) > 0) return Optional.empty();
        MatchType matchType = classifyMatch(inbound, paid);
        NearDupQueue queue = NearDupQueue.builder()
            .ndupClaimId(inbound.getClaimId()).ndupOrigClaimId(paid.getClaimId())
            .ndupMemberId(inbound.getMemberId()).ndupProvNpi(inbound.getProvNpi())
            .ndupDos(inbound.getDosFrom()).ndupCptCd(inbound.getCptCd())
            .ndupChargeAmt(inbound.getChargeAmt()).ndupMatchType(matchType)
            .ndupPendReason("NEAR-DUP-REVIEW").ndupCreateDt(todayAsInt()).ndupStatus("P").build();
        return Optional.of(queue);
    }
    private boolean isExactDuplicate(ClaimPayment inbound, ClaimPayment paid) {
        return inbound.getMemberId().equals(paid.getMemberId())
            && inbound.getProvNpi().equals(paid.getProvNpi())
            && inbound.getCptCd().equals(paid.getCptCd())
            && inbound.getDosFrom().equals(paid.getDosFrom())
            && inbound.getChargeAmt().compareTo(paid.getChargeAmt()) == 0
            && nullSafeEquals(inbound.getModifier1(), paid.getModifier1())
            && nullSafeEquals(inbound.getModifier2(), paid.getModifier2());
    }
    MatchType classifyMatch(ClaimPayment inbound, ClaimPayment paid) {
        boolean modDiff = !nullSafeEquals(inbound.getModifier1(), paid.getModifier1())
                       || !nullSafeEquals(inbound.getModifier2(), paid.getModifier2());
        boolean dosDiff = !inbound.getDosFrom().equals(paid.getDosFrom());
        boolean amtDiff = inbound.getChargeAmt().compareTo(paid.getChargeAmt()) != 0;
        if (modDiff && dosDiff && amtDiff) return MatchType.COMBINED;
        if (modDiff) return MatchType.MODIFIER;
        if (dosDiff) return MatchType.DATE_DRIFT;
        return MatchType.AMT_VAR;
    }
    BigDecimal chargeVariancePct(BigDecimal inbound, BigDecimal paid) {
        if (paid == null || paid.compareTo(BigDecimal.ZERO) == 0) return BigDecimal.ZERO;
        return inbound.subtract(paid).abs().divide(paid, 4, RoundingMode.HALF_UP)
            .multiply(new BigDecimal("100")).setScale(2, RoundingMode.HALF_UP);
    }
    private boolean nullSafeEquals(String a, String b) {
        if (a == null && b == null) return true;
        if (a == null || b == null) return false;
        return a.trim().equals(b.trim());
    }
    private int todayAsInt() {
        return Integer.parseInt(LocalDate.now().format(DateTimeFormatter.ofPattern("yyyyMMdd")));
    }
    public record EvaluationResult(String claimId, Outcome outcome, String matchedClaimId, MatchType matchType) {
        public enum Outcome { NEAR_DUP, CLEAN, SKIPPED }
        public static EvaluationResult nearDup(String claimId, String matchedId, MatchType type) {
            return new EvaluationResult(claimId, Outcome.NEAR_DUP, matchedId, type); }
        public static EvaluationResult clean(String claimId) {
            return new EvaluationResult(claimId, Outcome.CLEAN, null, null); }
        public static EvaluationResult skipped(String claimId) {
            return new EvaluationResult(claimId, Outcome.SKIPPED, null, null); }
    }
}