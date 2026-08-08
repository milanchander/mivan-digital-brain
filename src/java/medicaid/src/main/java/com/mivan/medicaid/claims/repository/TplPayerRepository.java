package com.mivan.medicaid.claims.repository;

import com.mivan.medicaid.claims.model.TplPayerFile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TplPayerRepository
        extends JpaRepository<TplPayerFile, TplPayerFile.TplPayerId> {

    List<TplPayerFile> findByIdMemberIdAndStatusCd(String memberId, String statusCd);

    List<TplPayerFile> findByIdMemberId(String memberId);
}
