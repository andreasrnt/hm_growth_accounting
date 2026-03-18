# Data Documentation Agent

## Overview

The AI agent that generates and maintains documentations at the column level as the 
model change. Its involve in with pull request that affects a dbt model and then suggest 
documentation updates as a pull request comment. The merges of the changes will be 
approved after human reviewed and gives the approval to merge.

---

## A. Architecture

### Trigger
The agent will be triggered by a GitHub Actions workflow on the pull request that
modifies any file under `models` and `tests`. This trigger will ensure the documentation
changes are reviewed at the same time as the model.

```
Model changed --> PR opened / updated --> GitHub Actions: detect changed .sql files
--> Agent runs for the changed models --> New proposed docs as PR comment --> 
Human reviews and approves --> Docs merged to schema.yml
```

### Inputs
For each changed model, the agent receives:
- Model SQL: the full `.sql` file
- Existing `schema.yml` entry for the model
- Git diff: what changed vs the previous version
- Context: describes the business, the project, and the goal

### Tools & APIs
1. **GitHub API** — fetch, write, read, propose the changes
2. **dbt Cloud API** — fetch compiled SQL and model lineage
3. **LLM API** — generate column descriptions given SQL + context

### How it Runs
The agent compares the current schema.yml against the updated file to identify the changes.
Only the changed columns will get a new proposed description. If theres no existing schema.yml
the agent will generates the description for all columns.

---

## B. Human-in-the-Loop Design

### Require Human Approval
The agent is not a decider, it's only propose. Every new documentation changes proposed, it 
requires human approval before merged.

### Review Flow
```
Agent proposed the changes with the pull request comment --> Reviewer read and edit if needed
--> Reviewer approve the changes with approval comments --> Merged
```

### Preventing Silent Bad Docs at Scale
- The agent instructured to create a short and accurate descriptions 
- The proposed will shown as a diff against the existing docs, to flag the changes
- The agent flags the columns where the description is uncertain for the ambigous column name

### Surfacing Changes to The Team
- PR comment on GitHub: to keeps everything documented in GitHub and visible to all reviewers
- Slack notification: to make sure the involved users are notified for the changes

---

## C. Failure Modes & Observability

### Failure Mode 1: Wrong Column Descriptions
The agent misunderstands the columns means and generate the wrong description. It might be
happen when the column name has ambiguity, make it sounds correct but it is not.

- **Detection:** If the team notices descriptions are off, it will be a signal to update the
prompt and or add more context.

- **Logging:** Log the model, column, timestamp, description, reviewer for every approval.

### Failure Mode 2: Agent Skips Changed Columns
The agent misses a newly added columns because of the fails without warning.

- **Detection:** After the run, automatically compare the column list from the model against
list in the proposed file. Block the merging until it resolved.

- **Logging:** Log the model, missing columns, timestamp, description, reviewer for every run.

### Failure Mode 3 — Agent Runs but PR Comment is Never Reviewed
Reviewers 100% trust the agent and approve without review it carefully. 

- **Detection:** Alert if a PR is merged without any approval comment from reviewer. Also
can add tracker to track time to approval of the pull request. If it's less than the
threshold, agent will add a new comment to notify the potential skipper.

- **Alerting:** Sent the daily list of pull request, add flag for missing or unapproved documentation
with log of reviewer and the timestamp of proposal and approval.

---

## D. Scope & Build Plan

### V1 — One Week Scope

**In Scope:**
- GitHub Actions trigger on PR for changed files
- LLM call to generate column descriptions for new and changed columns
- PR comment with proposed YAML files

**Out of Scope:**
- Auto commit on approval
- Support for existing models with complex lineage

### Measuring the Usefulness
What is success:
- **Time saved:** Comparing time for documentation between with agent against without agent. One of the 
goal of the agent is to reduce from days/hours to hours/minutes. If human or reviewers still spend
much time on fixing bad proposal, the agent not worth.
- **Adoption:** The usefullness for other engineers by start to use the flow without asking.
- **Coverage:** The production models covered with the agent increasing the non-empty description.

---

## Known Limitations & Tradeoffs

- **Cost:** Every triggers will call the LLM API, when the scale is increase it will increase the cost.
Need to monitor the agent performance and cost.
- **Knowledge:** The agent only knows on knowledge based on our prompt for the context and the files.
It needs to still update the context in the prompt, so the agent not do the improvisation and create
the wrong result.
- **Hallucinations:** It's happened for every LLM models, and might be impact to the description that
agent generate, especiallt for the columns with the ambigous or complex names. 
- **Human Involvement:** Human still the one who more understands the business logic begind the models.
The agent speeds up the documentation process, not replace the logic. Human approval is a must.