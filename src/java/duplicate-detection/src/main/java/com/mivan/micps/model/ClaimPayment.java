package com.mivan.micps.model;
import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
@Entity @Table(schema="MIVANCPS",name="CLAIM_PAYMENT")
@Data @NoArgsConstructor @AllArgsConstructor @Builder
public class ClaimPayment {
    @Id @Column(name="CLAIM_ID",length=20) private String claimId;
    @Column(name="MEMBER_ID",length=15,nullable=false) private String memberId;
    @Column(name="PROV_NPI",length=10,nullable=false) private String provNpi;
    @Column(name="DOS_FROM",nullable=false) private Integer dosFrom;
    @Column(name="DOS_TO") private Integer dosTo;
    @Column(name="CPT_CD",length=5,nullable=false) private String cptCd;
    @Column(name="MODIFIER_1",length=2) private String modifier1;
    @Column(name="MODIFIER_2",length=2) private String modifier2;
    @Column(name="CHARGE_AMT",precision=9,scale=2,nullable=false) private BigDecimal chargeAmt;
    @Column(name="PAID_AMT",precision=9,scale=2) private BigDecimal paidAmt;
    @Column(name="PAYMENT_STATUS_CD",length=2) private String paymentStatusCd;
    @Column(name="PAYMENT_DT") private Integer paymentDt;
}