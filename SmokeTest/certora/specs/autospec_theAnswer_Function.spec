import "summaries/Answer_base_summaries.spec";

methods {
    function theAnswer() external returns (uint256) envfree;
}

/// @title the_answer_returns_42
/// The function theAnswer() must always return the value 42, regardless of the caller,
/// block state, or any other environmental condition.
rule the_answer_returns_42 {
    uint256 result = theAnswer();
    assert result == 42, "theAnswer() must always return 42";
}