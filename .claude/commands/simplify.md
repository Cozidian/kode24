This is the **refactor phase** of TDD — only run this after all tests are green.

Review the code changed or added in the current feature for opportunities to simplify, remove duplication, and improve clarity. Specifically look for:

- Logic that can be extracted into a well-named private helper
- Pattern match clauses that can be merged or reordered for readability
- Overly defensive guards for cases that cannot happen given the data flow
- Log message strings that are inconsistent with the style of existing log entries
- LiveView template blocks that repeat structure already present elsewhere

Also review tests changed or added in the current feature for:

- Overlapping tests that assert the same behaviour from different angles with no additional coverage
- Redundant setup (fixtures or values that are set up but not exercised by the assertion)
- Tests whose description no longer matches what they actually assert
- Shared setup that could be extracted into a named fixture or `setup` block used by multiple tests
- Missing edge cases that the implementation clearly handles but no test covers

Make only changes that improve clarity or remove duplication — do not add new behaviour, new error handling, or speculative abstractions.

After each change, run `mix test` to confirm all tests still pass. When done, run `/precommit` to verify the full build is clean.
