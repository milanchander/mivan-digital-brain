package com.mivan.medicaid.claims.model;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDate;

/** Maps to DB2 TPL_PAYER_FILE — known TPL payers by member. Used by MMCOTPL0. */
@Data
@Entity
@Table(name = "TPL_PAYER_FILE")
public class TplPayerFile {

    @EmbeddedId
    private TplPayerId id;

    @Column(name = "PAYER_NAME", length = 40)
    private String payerName;

    @Column(name = "POLICY_NO", length = 20)
    private String policyNo;

    @Column(name = "EFFECTIVE_DT")
    private LocalDate effectiveDt;

    @Column(name = "TERM_DT")
    private LocalDate termDt;

    @Column(name = "STATUS_CD", length = 2)
    private String statusCd;

    public boolean isActiveOn(LocalDate dos) {
        return "AC".equals(statusCd)
                && (effectiveDt == null || !dos.isBefore(effectiveDt))
                && (termDt == null || !dos.isAfter(termDt));
    }

    @Embeddable
    @Data
    public static class TplPayerId implements java.io.Serializable {
        @Column(name = "MEMBER_ID", length = 15, nullable = false)
        private String memberId;

        @Column(name = "PAYER_ID", length = 10, nullable = false)
        private String payerId;
    }
}
