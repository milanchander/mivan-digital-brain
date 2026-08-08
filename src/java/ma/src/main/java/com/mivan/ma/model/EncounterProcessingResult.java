package com.mivan.ma.model;

import lombok.Builder;
import lombok.Data;

/** Non-persisted result DTO returned by the orchestrator for each member processed. */
@Data
@Builder
public class EncounterProcessingResult {

    private String mbi;
    private String hicn;
    private String contractId;
    private String encounterId;
    private boolean eligible;
    private boolean hccValid;
    private String rafTotal;
    private String submissionStatus;
    private String errorCode;
    private String errorMessage;

    public boolean isSuccess() {
        return "SU".equals(submissionStatus) || "AC".equals(submissionStatus);
    }
}
