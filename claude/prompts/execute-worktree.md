# Execution (with worktree)

Read through the entire plan from start to finish before doing anything. Then:

1. **Build an internal task list** — create an exhaustively granular, ordered task/todo list derived from the plan. Decompose every phase into sub-phases, every sub-phase into individual tasks, and every task into atomic sub-tasks. Each level of the hierarchy must be small enough that it maps to a single, verifiable action (e.g., one function, one test, one file edit). Do not stop decomposing until every leaf task is trivially completable. Each task at every level must be annotated with:
   - The sub-agent responsible for it.
   - Its dependencies (which tasks must complete before it can start).
   - Acceptance criteria (how to know it is done).
   - Its depth in the hierarchy (e.g., Phase 1 > Sub-phase 1.2 > Task 1.2.3 > Sub-task 1.2.3.1).

   Every leaf task that involves code changes must follow the **Red/Green/Refactor** TDD cycle. Decompose it into three explicit sub-tasks:
   1. **Red** — Write a failing test that defines the expected behavior. Run the test and confirm it fails.
   2. **Green** — Write the minimal implementation to make the failing test pass. Run the test and confirm it passes.
   3. **Refactor** — Clean up the implementation and test code without changing behavior. Run the test and confirm it still passes.
2. **Create a new worktree** — set up an isolated git worktree for this work.
3. **Execute phase by phase** — work through the plan in phase order. After completing each phase, verify its outputs before moving to the next.
4. **Verify before claiming completion** — run tests, linting, and type checks. Confirm all acceptance criteria are met. Do not mark work as done until verification passes.
