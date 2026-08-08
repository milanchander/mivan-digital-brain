package com.mivan.medicaid.claims.repository;

import com.mivan.medicaid.claims.model.MedicaidEligibility;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface MedicaidEligibilityRepository extends JpaRepository<MedicaidEligibility, String> {

    Optional<MedicaidEligibility> findByMemberIdAndStateCdAndStatusCd(
            String memberId, String stateCd, String statusCd);

    @Query("SELECT e FROM MedicaidEligibility e WHERE e.memberId = :memberId " +
           "AND e.stateCd = :stateCd AND e.statusCd = 'AC' " +
           "AND e.eligFromDt <= :dos AND (e.eligToDt IS NULL OR e.eligToDt >= :dos)")
    Optional<MedicaidEligibility> findActiveOnDos(
            @Param("memberId") String memberId,
            @Param("stateCd") String stateCd,
            @Param("dos") LocalDate dos);

    List<MedicaidEligibility> findByMcoIdAndStatusCd(String mcoId, String statusCd);

    List<MedicaidEligibility> findByDualEligIndAndStateCd(String dualEligInd, String stateCd);
}
