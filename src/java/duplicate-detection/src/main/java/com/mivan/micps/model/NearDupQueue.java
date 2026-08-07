package com.mivan.micps.model;
import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
@Entity @Table(schema="MIVANCPS",name="NEAR_DUP_QUEUE")
@Data @NoArgsConstructor @AllArgsConstructor @Builder
public class NearDupQueue {
    @Id @Column(name="NDUP_CLAIM_ID",length=20) private String ndupClaimId;
    @Column(name="NDUP_ORIG_CLAIM_ID",length=20,nullable=false) private String ndupOrigClaimId;
    @Column(name="NDUP_MEMBER_ID",length=15,nullable=false) private String ndupMemberId;
    @Column(name="NDUP_PROV_NPI",length=10,nullable=false) private String ndupProvNpi;
    @Column(name="NDUP_DOS",nullable=false) private Integer ndupDos;
    @Column(name="NDUP_CPT_CD",length=5,nullable=false) private String ndupCptCd;
    @Column(name="NDUP_CHARGE_AMT",precision=9,scale=2,nullable=false) private BigDecimal ndupChargeAmt;
    @Column(name="NDUP_MATCH_TYPE",length=10,nullable=false) @Enumerated(EnumType.STRING) private MatchType ndupMatchType;
    @Column(name="NDUP_PEND_REASON",length=20) private String ndupPendReason;
    @Column(name="NDUP_CREATE_DT",nullable=false) private Integer ndupCreateDt;
    @Column(name="NDUP_STATUS",length=1) private String ndupStatus;
}