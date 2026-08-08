package com.mivan.medicaid.claims.repository;

import com.mivan.medicaid.claims.model.StateContract;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface StateContractRepository
        extends JpaRepository<StateContract, StateContract.StateContractId> {

    Optional<StateContract> findByIdStateCdAndIdMcoId(String stateCd, String mcoId);
}
