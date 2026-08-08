package com.mivan.medicaid.claims.repository;

import com.mivan.medicaid.claims.model.MedicaidLiability;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface MedicaidLiabilityRepository extends JpaRepository<MedicaidLiability, String> {

    Optional<MedicaidLiability> findByClaimIdAndStatusCd(String claimId, String statusCd);

    List<MedicaidLiability> findByMemberIdAndStateCd(String memberId, String stateCd);

    List<MedicaidLiability> findByStateCdAndStatusCd(String stateCd, String statusCd);
}
