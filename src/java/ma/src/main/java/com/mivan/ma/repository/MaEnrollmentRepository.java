package com.mivan.ma.repository;

import com.mivan.ma.model.MaEnrollment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface MaEnrollmentRepository extends JpaRepository<MaEnrollment, String> {

    Optional<MaEnrollment> findByMbiAndContractIdAndStatusCd(
            String mbi, String contractId, String statusCd);

    List<MaEnrollment> findByContractIdAndEffDateBeforeAndTermDateAfter(
            String contractId, LocalDate effDate, LocalDate termDate);

    List<MaEnrollment> findByDualStatusAndLisLevel(String dualStatus, String lisLevel);
}
