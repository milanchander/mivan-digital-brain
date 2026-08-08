package com.mivan.ma.service;

import com.mivan.ma.model.*;
import com.mivan.ma.repository.MaEncounterStagingRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Builds encounter staging records from validated HCCs and enrollment data.
 * Java equivalent of COBOL subprogram MAENCBL0.
 *
 * Generates encounter IDs using contractId + planId + UUID (replacing COBOL DB2 SEQUENCE).
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class EncounterBuilderService {

    private final MaEncounterStagingRepository stagingRepository;

    /**
     * Builds one MaEncounterStaging per validated HCC record and persists to staging table.
     * Mirrors MAENCBL0 paragraphs 1000-GENERATE-ENCOUNTER-ID through 3000-INSERT-STAGING.
     */
    public List<MaEncounterStaging> buildAndStageEncounters(
            MaEnrollment enrollment,
            List<MaHccRecord> validatedHccs,
            MaRafScore rafScore) {

        List<MaEncounterStaging> stagingRecords = validatedHccs.stream()
                .map(hcc -> buildStagingRecord(enrollment, hcc))
                .toList();

        List<MaEncounterStaging> saved = stagingRepository.saveAll(stagingRecords);
        log.info("Staged {} encounters for mbi={}", saved.size(), enrollment.getMbi());
        return saved;
    }

    private MaEncounterStaging buildStagingRecord(MaEnrollment e, MaHccRecord hcc) {
        MaEncounterStaging s = new MaEncounterStaging();
        s.setEncounterId(generateEncounterId(e));
        s.setTransactionType("01");
        s.setSubmissionType("PR");
        s.setMbi(e.getMbi());
        s.setHicn(e.getHicn());
        s.setContractId(e.getContractId());
        s.setPlanId(e.getPlanId());
        s.setBillingNpi(hcc.getProviderNpi());
        s.setRenderingNpi(hcc.getProviderNpi());
        s.setDosFrom(hcc.getDosFrom());
        s.setDosThru(hcc.getDosThru());
        s.setSubmissionStatus("PE");
        return s;
    }

    private String generateEncounterId(MaEnrollment e) {
        String raw = e.getContractId() + e.getPlanId()
                + UUID.randomUUID().toString().replace("-", "");
        return raw.substring(0, Math.min(raw.length(), 20));
    }
}
