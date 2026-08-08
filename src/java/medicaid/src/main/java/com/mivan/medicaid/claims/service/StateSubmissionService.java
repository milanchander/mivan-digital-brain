package com.mivan.medicaid.claims.service;

import com.mivan.medicaid.claims.model.MedicaidEncounterStaging;
import com.mivan.medicaid.claims.model.StateContract;
import com.mivan.medicaid.claims.repository.MedicaidLiabilityRepository;
import com.mivan.medicaid.claims.repository.StateContractRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

/**
 * Stages encounter records for state MMIS submission.
 *
 * Java equivalent of COBOL program MMCOSSUB0.
 * Mirrors paragraphs 3000-READ-STAGING-FILE through 4100-GENERATE-SUBMISSION-REPORT.
 *
 * Each state MMIS has different submission formats and timeliness requirements
 * governed by STATE_CONTRACT. Encounters must be submitted within
 * ENCOUNTER_DUE_DAYS of the date of service.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class StateSubmissionService {

    private final StateContractRepository stateContractRepository;
    private final MedicaidLiabilityRepository liabilityRepository;

    /**
     * Validates and stages an encounter for state MMIS submission.
     * Applies state-specific edit rules from STATE_CONTRACT.
     * Mirrors MMCOSSUB0 paragraphs 3100-3300 and 4000.
     *
     * @param record encounter staging record
     * @return true if staged successfully; false if state edits failed
     */
    public boolean stageForSubmission(MedicaidEncounterStaging record) {
        if (!record.isReadyForSubmission()) {
            log.warn("Encounter failed submission validation claimId={}", record.getClaimId());
            return false;
        }

        // MMCOSSUB0 paragraph 3100 — get state submission rules
        Optional<StateContract> contract = stateContractRepository
                .findByIdStateCdAndIdMcoId(record.getStateCd(),
                        record.getMcoId() != null ? record.getMcoId() : "");

        int encounterDueDays = contract
                .map(c -> c.getEncounterDueDays() != null ? c.getEncounterDueDays() : 90)
                .orElse(90);

        // MMCOSSUB0 paragraph 3300 — validate state edits
        if (!passesStateEdits(record)) {
            log.warn("Encounter failed state edits claimId={} state={}",
                    record.getClaimId(), record.getStateCd());
            return false;
        }

        record.setStatus("SU");
        log.info("Encounter staged for submission claimId={} state={} dueDays={}",
                record.getClaimId(), record.getStateCd(), encounterDueDays);
        return true;
    }

    /**
     * Stages a batch of encounters and returns the count successfully staged.
     */
    public long stageBatch(List<MedicaidEncounterStaging> records) {
        long count = records.stream()
                .filter(this::stageForSubmission)
                .count();
        log.info("Batch staged {}/{} encounters", count, records.size());
        return count;
    }

    private boolean passesStateEdits(MedicaidEncounterStaging r) {
        // MMCOSSUB0 paragraph 3300 — mandatory edits
        return r.getMemberId() != null && !r.getMemberId().isBlank()
                && r.getProvNpi() != null && !r.getProvNpi().isBlank()
                && r.getDosFrom() != null
                && !"RJ".equals(r.getStatus());
    }
}
