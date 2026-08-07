package com.mivan.micps.repository;
import com.mivan.micps.model.ClaimPayment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
public interface ClaimPaymentRepository extends JpaRepository<ClaimPayment, String> {
    @Query("SELECT c FROM ClaimPayment c WHERE c.memberId = :memberId AND c.provNpi = :provNpi AND c.cptCd = :cptCd AND c.dosFrom BETWEEN :dosLow AND :dosHigh AND c.paymentStatusCd = 'PD' AND c.claimId <> :excludeClaimId")
    List<ClaimPayment> findPaidCandidates(@Param("memberId") String memberId, @Param("provNpi") String provNpi, @Param("cptCd") String cptCd, @Param("dosLow") int dosLow, @Param("dosHigh") int dosHigh, @Param("excludeClaimId") String excludeClaimId);
}