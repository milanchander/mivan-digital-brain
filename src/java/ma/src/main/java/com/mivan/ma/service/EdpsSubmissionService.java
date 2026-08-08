package com.mivan.ma.service;

import com.mivan.ma.model.MaEncounterStaging;
import com.mivan.ma.repository.MaEncounterStagingRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;

/**
 * Submits staged encounters to the CMS Encounter Data Processing System (EDPS).
 * Java equivalent of COBOL subprogram MAEDPSUB0.
 *
 * In production, this service would invoke the CMS EDPS REST/MQ endpoint.
 * Currently marks records as SUBMITTED and updates the staging table.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class EdpsSubmissionService {

    private final MaEncounterStagingRepository stagingRepository;

    /**
     * Validates and submits a list of staged encounters to EDPS.
     * Mirrors MAEDPSUB0 paragraphs 1000-VALIDATE through 3000-UPDATE-STAGING-STATUS.
     *
     * @return list of successfully submitted records
     */
    public List<MaEncounterStaging> submitToEdps(List<MaEncounterStaging> records) {
        List<MaEncounterStaging> valid = records.stream()
                .filter(this::isValid)
                .toList();

        valid.forEach(r -> {
            r.setSubmissionStatus("SU");
            r.setSubmitDate(LocalDate.now());
        });

        List<MaEncounterStaging> submitted = stagingRepository.saveAll(valid);
        log.info("Submitted {} encounters to EDPS", submitted.size());

        int rejected = records.size() - valid.size();
        if (rejected > 0) {
            log.warn("{} records failed validation and were not submitted", rejected);
        }
        return submitted;
    }

    /**
     * Re-queries pending records and re-submits — supports retry after EDPS downtime.
     */
    public List<MaEncounterStaging> resubmitPending(String contractId) {
        List<MaEncounterStaging> pending =
                stagingRepository.findByContractIdAndSubmissionStatus(contractId, "PE");
        log.info("Re-submitting {} pending encounters for contractId={}", pending.size(), contractId);
        return submitToEdps(pending);
    }

    private boolean isValid(MaEncounterStaging r) {
        return r.getMbi() != null && !r.getMbi().isBlank()
                && r.getContractId() != null && !r.getContractId().isBlank()
                && r.getDosFrom() != null;
    }
}
