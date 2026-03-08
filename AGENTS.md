---
description: Project instructions for coding agents
scope: repository
role: Orchestrator Agent
---

<instructions>
  <purpose>
    <summary>
      This repo is a GitHub Actions-based AI orchestration system. When GitHub events fire
      (issues, PR comments, PR reviews, etc.), the `orchestrator-agent` workflow:
      1. Assembles a structured prompt from a template + the event JSON payload.
      2. Spins up a devcontainer with the full toolchain pre-installed.
      3. Runs `opencode --agent Orchestrator` inside the container, which reads the prompt
         and delegates work to specialized sub-agents defined in `.opencode/agents/`.
    </summary>
    <guidance>
      Use this file as the default operating guide for coding agents working in this repo.
    </guidance>
  </purpose>

  <tech_stack>
    <item>opencode CLI — primary agent runtime (`opencode --model zai-coding-plan/glm-5 --agent Orchestrator`)</item>
    <item>ZhipuAI GLM models via `ZHIPU_API_KEY`</item>
    <item>GitHub Actions — workflow trigger and runner</item>
    <item>devcontainers/ci — executes opencode inside a reproducible container</item>
    <item>.NET SDK 10 + Aspire workload + Avalonia templates (installed in devcontainer)</item>
    <item>Bun — JS runtime (installed in devcontainer)</item>
    <item>uv — Python package manager (installed in devcontainer)</item>
    <item>MCP servers: `@modelcontextprotocol/server-sequential-thinking`, `@modelcontextprotocol/server-memory`</item>
  </tech_stack>

  <repository_map>
    <entry>
      <path>.github/workflows/orchestrator-agent.yml</path>
      <description>Primary workflow — assembles prompt, logs into GHCR, runs opencode in devcontainer</description>
    </entry>
    <entry>
      <path>.github/workflows/prompts/orchestrator-agent-prompt.md</path>
      <description>Prompt template with `__EVENT_DATA__` placeholder replaced at runtime with structured event context + raw JSON</description>
    </entry>
    <entry>
      <path>.opencode/agents/orchestrator.md</path>
      <description>Orchestrator agent definition — coordinates all specialist agents, never writes code directly</description>
    </entry>
    <entry>
      <path>.opencode/agents/</path>
      <description>All specialist agent definitions (developer, code-reviewer, planner, devops-engineer, github-expert, etc.)</description>
    </entry>
    <entry>
      <path>.opencode/commands/</path>
      <description>Reusable command prompts (e.g., `orchestrate-new-project.md`, `grind-pr-reviews.md`, `fix-failing-workflows.md`)</description>
    </entry>
    <entry>
      <path>.opencode/opencode.json</path>
      <description>opencode config — MCP server definitions (sequential-thinking, memory)</description>
    </entry>
    <entry>
      <path>.github/.devcontainer/Dockerfile</path>
      <description>Devcontainer image — installs .NET SDK, Bun, uv, and opencode CLI (build context for publish-docker workflow)</description>
    </entry>
    <entry>
      <path>.github/.devcontainer/devcontainer.json</path>
      <description>Build-time devcontainer config — references Dockerfile and includes Features (node, python, gh CLI)</description>
    </entry>
    <entry>
      <path>.devcontainer/devcontainer.json</path>
      <description>Consumer devcontainer config — pulls prebuilt image from GHCR, no local build required</description>
    </entry>
    <entry>
      <path>.github/workflows/publish-docker.yml</path>
      <description>Builds raw Dockerfile and pushes to GHCR with main-latest and main-&lt;run_number&gt; tags</description>
    </entry>
    <entry>
      <path>.github/workflows/prebuild-devcontainer.yml</path>
      <description>Layers devcontainer Features on the published Docker image, triggered by workflow_run after Publish Docker</description>
    </entry>
    <entry>
      <path>test/</path>
      <description>Shell-based tests: devcontainer build, tool availability, and prompt assembly validation</description>
    </entry>
    <entry>
      <path>test/fixtures/</path>
      <description>Sample GitHub webhook payloads for local testing (issues, PRs, comments, reviews)</description>
    </entry>
  </repository_map>

  <environment_setup>
    <step order="1">
      <title>Required secrets (GitHub Actions)</title>
      <instruction>`ZHIPU_API_KEY` — ZhipuAI model access; set in repo Settings → Secrets.</instruction>
      <instruction>`GITHUB_TOKEN` — provided automatically by Actions; no manual setup needed.</instruction>
    </step>
    <step order="2">
      <title>Devcontainer image cache</title>
      <instruction>Image is cached at `ghcr.io/${{ github.repository }}/devcontainer`. `publish-docker.yml` builds the raw Dockerfile; `prebuild-devcontainer.yml` layers Features on top.</instruction>
      <instruction>Login uses `GITHUB_TOKEN` via `docker/login-action` targeting `ghcr.io`.</instruction>
      <instruction>Set repo variable `VERSION_PREFIX` (e.g., `1.0`) for versioned image tags (`main-1.0.&lt;run_number&gt;`).</instruction>
    </step>
  </environment_setup>

  <runbook>
    <run>
      <name>Trigger the workflow</name>
      <note>Open or comment on an issue, open/push to a PR, or submit a review. The `orchestrator-agent` workflow fires automatically.</note>
    </run>
    <run>
      <name>Test devcontainer build</name>
      <command>`bash test/test-devcontainer-build.sh`</command>
    </run>
    <run>
      <name>Test tool availability inside devcontainer</name>
      <command>`bash test/test-devcontainer-tools.sh`</command>
    </run>
    <run>
      <name>Test prompt assembly</name>
      <command>`bash test/test-prompt-assembly.sh`</command>
    </run>
  </runbook>

  <testing_guidance>
    <guidance>Tests are shell scripts in `test/`. Run them directly with `bash`.</guidance>
    <commands>
      <command>Run all tests: `bash test/test-devcontainer-build.sh && bash test/test-devcontainer-tools.sh && bash test/test-prompt-assembly.sh`</command>
      <command>Prompt assembly test uses fixtures from `test/fixtures/` — add new fixture payloads there when testing new event types.</command>
    </commands>
  </testing_guidance>

  <coding_conventions>
    <rule>Keep changes minimal and targeted to the requested behavior.</rule>
    <rule>Avoid broad refactors unless the task explicitly requires them.</rule>
    <rule>Do not hardcode secrets/tokens.</rule>
    <rule>When editing `.github/workflows/prompts/orchestrator-agent-prompt.md`, preserve the `__EVENT_DATA__` placeholder — the workflow relies on it for sed substitution.</rule>
    <rule>When editing `.opencode/agents/orchestrator.md`, keep the delegation-depth limit (≤2) and the "never write code directly" constraint intact.</rule>
    <rule>Pin action versions by SHA in workflow files (already enforced for `actions/checkout` and `docker/login-action`).</rule>
  </coding_conventions>

  <agent_specific_guardrails>
    <rule>The Orchestrator agent must never write code directly — it delegates to specialist agents via the `task` tool.</rule>
    <rule>Prompt assembly pipeline:
      1. Read template from `.github/workflows/prompts/orchestrator-agent-prompt.md`.
      2. Prepend structured event context (event name, action, actor, repo, ref, SHA).
      3. Append raw event JSON from `${{ toJson(github.event) }}`.
      4. Write assembled prompt to `.assembled-orchestrator-prompt.md` and export path via `GITHUB_ENV`.
    </rule>
    <rule>Do not add a second top-level `name:`, `on:`, or `jobs:` block to any single workflow YAML file — duplicate keys silently overwrite and drop triggers.</rule>
    <rule>`.opencode/` is checked out by `actions/checkout`; do not COPY it separately in the Dockerfile.</rule>
    <rule>The Dockerfile lives at `.github/.devcontainer/Dockerfile`. The consumer `.devcontainer/devcontainer.json` uses `"image:"` — it does not build locally.</rule>
  </agent_specific_guardrails>

  <validation_before_handoff>
    <step order="1">Run shell tests: `bash test/test-prompt-assembly.sh` for prompt changes; `bash test/test-devcontainer-tools.sh` for Dockerfile changes.</step>
    <step order="2">
      Validate workflow YAML has exactly one top-level `name:`, `on:`, and `jobs:` key:
      `grep -c "^name:" .github/workflows/orchestrator-agent.yml  # expect 1`
    </step>
    <step order="3">
      Summarize:
      - What changed
      - What was validated
      - Any remaining risk (especially secret-dependent paths or devcontainer image cache misses)
    </step>
  </validation_before_handoff>

  <tool_use_instructions>
    <instruction id="querying_microsoft_documentation">
      <applyTo>**</applyTo>
      <title>Querying Microsoft Documentation</title>
      <tools>
        <tool>microsoft_docs_search</tool>
        <tool>microsoft_docs_fetch</tool>
        <tool>microsoft_code_sample_search</tool>
      </tools>
      <guidance>
        These MCP tools can search and fetch Microsoft's latest official documentation and code samples, which may be newer or more detailed than model training data.
      </guidance>
      <guidance>
        For specific and narrowly defined questions involving native Microsoft technologies (C#, F#, ASP.NET Core, Microsoft.Extensions, NuGet, Entity Framework, and the dotnet runtime), use these tools for research.
        When writing code, prioritize using information retrieved from these tools to ensure accuracy and up-to-date practices, especially for newer features or libraries.
        Before writing any code involving Microsoft technologies, always check for relevant documentation or code samples using these tools to ensure the most current and accurate information is being used.
      </guidance>
    </instruction>

    <instruction id="sequential_thinking_default_usage">
      <applyTo>*</applyTo>
      <title>Sequential Thinking for Complex Problem Solving</title>
      <tools>
        <tool>sequential_thinking</tool>
      </tools>
      <guidance>
        Use sequential thinking for all requests except the most trivial, single-step requests (for example, minimal formatting changes or direct one-line lookups).
      </guidance>
      <guidance>
        The sequential_thinking tool enables structured, step-by-step problem analysis with the ability to revise, branch, and adjust reasoning paths dynamically.
        Use this tool when:
        - Breaking down complex problems into manageable steps
        - Planning and design work that may require revision
        - Analyzing situations where the full scope is unclear initially
        - Conducting analysis that might need course correction
        - Making architectural or design decisions
        - Encountering unexpected issues or errors that require systematic debugging
        - Filtering out irrelevant information while maintaining context
        - Working through tasks that need to maintain context over multiple steps
      </guidance>
      <guidance>
        The tool supports dynamic thinking processes by allowing you to:
        - Revise previous thoughts when new understanding emerges
        - Branch into alternative reasoning paths
        - Adjust the estimated total number of thoughts as complexity becomes apparent
        - Mark when additional thinking steps are needed beyond original estimates
      </guidance>
    </instruction>

    <instruction id="memory_default_usage">
      <applyTo>*</applyTo>
      <title>Knowledge Graph Memory for Context Persistence</title>
      <tools>
        <tool>create_entities</tool>
        <tool>create_relations</tool>
        <tool>add_observations</tool>
        <tool>delete_entities</tool>
        <tool>delete_observations</tool>
        <tool>delete_relations</tool>
        <tool>read_graph</tool>
        <tool>search_nodes</tool>
        <tool>open_nodes</tool>
      </tools>
      <guidance>
        Use memory for all requests except the most trivial, single-step requests, and persist relevant user/project context when it helps future task continuity.
      </guidance>
      <guidance>
        The memory MCP server provides a persistent knowledge graph for storing and retrieving context across conversations.
        Store information about:
        - User preferences, communication styles, and working patterns
        - Project-specific configurations, patterns, and conventions
        - Technical decisions, rationale, and architectural choices
        - Recurring challenges, solutions, and workarounds discovered
        - Team members, their roles, and areas of expertise
        - Tool configurations, CLI paths, authentication mechanisms
        - Build patterns, deployment strategies, and environment setups
      </guidance>
      <guidance>
        Knowledge graph concepts:
        - **Entities**: Primary nodes with a name, type (e.g., "person", "project", "tool"), and observations
        - **Relations**: Directed connections between entities in active voice (e.g., "works_at", "depends_on", "configures")
        - **Observations**: Atomic facts stored as strings attached to entities (one fact per observation)
      </guidance>
      <guidance>
        Tool usage patterns:
        - Use create_entities to establish new concepts, people, projects, or tools
        - Use create_relations to connect related entities and build context
        - Use add_observations to record facts, preferences, or discoveries about entities
        - Use search_nodes to find relevant context based on keywords across names, types, and observations
        - Use open_nodes to retrieve specific entities by name for detailed information
        - Use read_graph to get a complete view of all stored knowledge when planning or reviewing
        - Use delete operations to clean up outdated or incorrect information
      </guidance>
      <guidance>
        At the start of complex tasks, search or read relevant memory to leverage previous learnings.
        After completing significant work, update memory with new patterns, configurations, or insights discovered.
      </guidance>
    </instruction>
  </tool_use_instructions>
</instructions>
