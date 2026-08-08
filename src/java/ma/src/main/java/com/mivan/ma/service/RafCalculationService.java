package com.mivan.ma.service;

import com.mivan.ma.model.MaEnrollment;
import com.mivan.ma.model.MaHccRecord;
import com.mivan.ma.model.MaRafScore;
import com.mivan.ma.repository.MaHccRecordRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.List;

/**
 * Calculates the CMS-HCC Risk Adjustment Factor (RAF) score for a member.
 * Java equivalent of COBOL subprogram MARAFCL0.
 *
 * RAF = demographic score + sum(HCC coefficients) + interaction adjustments
 *       + LIS adder + dual adder
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RafCalculationService {

    private final MaHccRecordRepository hccRecordRepository;

    private static final BigDecimal DEMO_BASE = new BigDecimal("0.387");
    private static final int SCALE = 6;

    /**
     * Builds and returns a populated MaRafScore for the member.
     * Mirrors MARAFCL0 paragraphs 1000-GET-DEMO-FACTOR through 4000-CALCULATE-TOTAL-RAF.
     */
    public MaRafScore calculateRaf(MaEnrollment enrollment,
                                   List<MaHccRecord> validatedHccs,
                                   String paymentYear) {
        MaRafScore score = new MaRafScore();
        score.setMbi(enrollment.getMbi());
        score.setHicn(enrollment.getHicn());
        score.setContractId(enrollment.getContractId());
        score.setPlanId(enrollment.getPlanId());
        score.setPaymentYear(paymentYear);
        score.setModelType("CMS");
        score.setNewEnrolleeInd("N");
        score.setHccCount(validatedHccs.size());

        BigDecimal demoScore = deriveDemoScore(enrollment);
        score.setDemographicScore(demoScore);

        BigDecimal diseaseScore = validatedHccs.stream()
                .filter(h -> h.getRafCoefficient() != null)
                .map(MaHccRecord::getRafCoefficient)
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .setScale(SCALE, RoundingMode.HALF_UP);
        score.setDiseaseScore(diseaseScore);

        score.setInteractionScore(BigDecimal.ZERO.setScale(SCALE));
        score.setLisAdder(deriveLisAdder(enrollment));
        score.setDualAdder(deriveDualAdder(enrollment));

        BigDecimal total = demoScore
                .add(diseaseScore)
                .add(score.getLisAdder())
                .add(score.getDualAdder())
                .setScale(SCALE, RoundingMode.HALF_UP);
        score.setTotalRaf(total);
        score.setPriorRaf(BigDecimal.ZERO.setScale(SCALE));
        score.setRafDelta(total.setScale(SCALE, RoundingMode.HALF_UP));
        score.setCalcDate(LocalDate.now());
        score.setStatus("00");

        log.info("RAF calculated mbi={} total={}", enrollment.getMbi(), total);
        return score;
    }

    private BigDecimal deriveDemoScore(MaEnrollment e) {
        return DEMO_BASE.setScale(SCALE, RoundingMode.HALF_UP);
    }

    private BigDecimal deriveLisAdder(MaEnrollment e) {
        if (e.getLisLevel() == null) return BigDecimal.ZERO.setScale(SCALE);
        return switch (e.getLisLevel().trim()) {
            case "01" -> new BigDecimal("0.194000");
            case "02" -> new BigDecimal("0.228000");
            case "03" -> new BigDecimal("0.423000");
            default   -> BigDecimal.ZERO.setScale(SCALE);
        };
    }

    private BigDecimal deriveDualAdder(MaEnrollment e) {
        if ("FD".equals(e.getDualStatus())) return new BigDecimal("0.163000");
        if ("PD".equals(e.getDualStatus())) return new BigDecimal("0.105000");
        return BigDecimal.ZERO.setScale(SCALE);
    }
}
