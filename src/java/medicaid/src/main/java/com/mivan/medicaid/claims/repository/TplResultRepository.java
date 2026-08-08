package com.mivan.medicaid.claims.repository;

import com.mivan.medicaid.claims.model.TplResult;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface TplResultRepository extends JpaRepository<TplResult, String> {

    Optional<TplResult> findByClaimIdAndStatusCd(String claimId, String statusCd);

    List<TplResult> findByMemberIdAndStatusCd(String memberId, String statusCd);
}
