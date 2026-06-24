import "summaries/Answer_base_summaries.spec";

methods {
    function theAnswer() external returns (uint256) envfree;
}

/// @title theAnswer_returns_42
/// Property 1: The function theAnswer() always returns the constant value 42.
rule theAnswer_returns_42 {
    uint256 result = theAnswer();
    assert result == 42, "theAnswer() must always return 42";
}
