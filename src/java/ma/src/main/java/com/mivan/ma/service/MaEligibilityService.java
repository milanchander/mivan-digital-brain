package com.mivan.ma.service;

import com.mivan.ma.model.MaEnrollment;
import com.mivan.ma.repository.MaEnrollmentRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.Optional;

/**
 * Verifies MA eligibility for a member.
 * Java equivalent of COBOL subprogram MAELGCK0.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MaEligibilityService {

    private final MaEnrollmentRepository enrollmentRepository;

    /**
     * Returns true if the member has active MA enrollment on the given date
     * for the specified contract. Mirrors MAELGCK0 DB2 SELECT logic.
     */
    public boolean isEligible(String mbi, String contractId, LocalDate asOfDate) {
        Optional<MaEnrollment> enrollment =
                enrollmentRepository.findByMbiAndContractIdAndStatusCd(mbi, contractId, "AC");
        if (enrollment.isEmpty()) {
            log.debug("No active enrollment found for mbi={} contractId={}", mbi, contractId);
            return false;
        }
        MaEnrollment e = enrollment.get();
        boolean inRange = !asOfDate.isBefore(e.getEffDate())
                && (e.getTermDate() == null || !asOfDate.isAfter(e.getTermDate()));
        if (!inRange) {
            log.debug("Enrollment out of range for mbi={} asOfDate={}", mbi, asOfDate);
        }
        return inRange;
    }

    /**
     * Returns the enrollment record for further processing.
     */
    public Optional<MaEnrollment> getEnrollment(String mbi, String contractId) {
        return enrollmentRepository.findByMbiAndContractIdAndStatusCd(mbi, contractId, "AC");
    }
}
