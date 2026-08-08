package com.mivan.ma.repository;

import com.mivan.ma.model.MaEncounterStaging;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface MaEncounterStagingRepository extends JpaRepository<MaEncounterStaging, String> {

    List<MaEncounterStaging> findByMbiAndSubmissionStatus(String mbi, String submissionStatus);

    List<MaEncounterStaging> findByContractIdAndSubmissionStatus(
            String contractId, String submissionStatus);

    List<MaEncounterStaging> findBySubmissionStatus(String submissionStatus);
}
