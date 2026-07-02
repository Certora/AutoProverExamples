import "summaries/Answer_base_summaries.spec";

methods {
    function theAnswer() external returns (uint256) envfree;
}

/// @title theAnswer_returns_42
/// Property 1: Calling theAnswer() must always return exactly the uint256 value 42.
rule theAnswer_returns_42 {
    uint256 result = theAnswer();
    assert result == 42, "theAnswer() must always return 42";
}

/// @title theAnswer_no_state_change
/// theAnswer() must not modify any contract state (behavioral purity).
rule theAnswer_no_state_change {
    storage before = lastStorage;
    theAnswer();
    assert before == lastStorage, "theAnswer() must not modify state";
}
