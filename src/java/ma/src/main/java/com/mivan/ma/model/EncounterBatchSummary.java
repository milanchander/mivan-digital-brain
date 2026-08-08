package com.mivan.ma.model;

import lombok.Builder;
import lombok.Data;
import java.util.List;

/** Batch-level summary returned by the orchestrator after processing a full enrollment file. */
@Data
@Builder
public class EncounterBatchSummary {

    private int inputCount;
    private int eligibleCount;
    private int ineligibleCount;
    private int hccValidCount;
    private int hccRejectCount;
    private int encounterCount;
    private int submitCount;
    private int errorCount;
    private List<EncounterProcessingResult> errors;

    public int getReturnCode() {
        return errorCount > 0 ? 8 : 0;
    }
}
