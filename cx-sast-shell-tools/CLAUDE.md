# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A collection of standalone PowerShell scripts for bulk/admin operations against Checkmarx products:
- **Checkmarx One / AST** (`AST-*.ps1`) — the current SaaS platform, REST API under `support/rest/cxone/`.
- **Checkmarx SAST** (classic, on-prem, `SAST-*.ps1`) — REST API under `support/rest/sast/`, with a SOAP fallback under `support/soap/` for older (v9) instances.
- A few misc/legacy top-level scripts (`batchScan.ps1`, `bulkExporter.ps1`, `createUsersByCsv.ps1`, etc.) that predate the `AST-`/`SAST-` naming convention but follow the same patterns.

There is no build, package manifest, test suite, or linter in this repo — it's plain PowerShell (`.ps1`), run directly.

## Running scripts

Scripts must be run **from the repository root**, because they dot-source helpers with paths relative to the repo root (e.g. `. "support/debug.ps1"`), not relative to the script's own location.

```powershell
./AST-AddScmScanTags.ps1 -csvPath ".\projects.csv"
```

Most scripts accept a `-dbg` switch to enable verbose `Write-Debug` output (API URLs, request bodies). This is wired through `support/debug.ps1`'s `setupDebug` function, which flips `$global:DebugPreference`.

Before running any top-level script, its **config block near the top of the file must be filled in** — tenant name, API key/PAT, and region URLs for CxOne scripts (`$cx1Tenant`, `$PAT`, `$cx1URL`, `$cx1TokenURL`, `$cx1IamURL`), or server URL/credentials for SAST scripts (`$sast_url`, `-username`/`-password` or PAT). These are plain script variables, not env vars or a secrets file — never commit real tenant names or tokens into these blocks.

There are no automated tests. Validate changes by running the script against a real (ideally non-prod) tenant/instance and inspecting output/CSV logs.

## Architecture

**Two layers:**

1. **Top-level orchestration scripts** (repo root) — the actual tools a user runs. They parse `param()`/CLI args, read/write CSVs, do business logic (matching, merging, filtering), and call into the support layer for every actual API call.
2. **`support/`** — thin, single-purpose building blocks, one script per API call, invoked with `&"support/rest/.../foo.ps1" <args>` (call operator, since these are scripts not functions). Organized by API family:
   - `support/rest/cxone/` — Checkmarx One REST endpoints (projects, SCM/repo settings, protected branches, query editor, presets, groups/users, scans, SCA recalc, etc.)
   - `support/rest/sast/` — Checkmarx SAST classic REST endpoints (projects, users, teams, scans, reports, git settings, etc.)
   - `support/rest/cxreporting/` — CxSAST reporting-service endpoints
   - `support/soap/` — legacy SOAP calls (audit queries, report generation, v9-compat login)
   - `support/rest_util.ps1` — shared helpers: `GetAuthHeaders`, `GetRestHeadersForJsonRequest`, `GetQueryStringFromHashtable`
   - `support/debug.ps1` — `setupDebug` for the `-dbg` switch

**Session object convention:** login scripts (`support/rest/cxone/apiTokenLogin.ps1`, `support/rest/sast/login.ps1` / `loginV2.ps1`) return a `$session` hashtable (`auth_header`, `base_url`, `expires_at`, plus API-specific fields like `tenant`/`auth_url` for CxOne or `soap_session` for SAST v9 compat). Every subsequent `support/` call takes this `$session` as its first positional argument and builds request headers from it via `GetRestHeadersForJsonRequest`. Top-level scripts always start with a login call, then thread the resulting `$session` through every following support-script call.

**Auth differs by product:**
- CxOne: OAuth2 `refresh_token` grant against the tenant's IAM realm (`$cx1TokenURL = "https://iam.checkmarx.net/auth/realms/$cx1Tenant"`), using a long-lived API key (`$PAT`) as the refresh token.
- SAST classic: OIDC token endpoint at `/cxrestapi/auth/identity/connect/token`, either username/password or PAT-based refresh token; `loginV2.ps1` additionally negotiates a SOAP login first and branches its `client_id`/`scope` based on whether the target is a v9 instance.

**Common script shape for bulk operations** (most `AST-*`/`SAST-*` scripts): take a `-csvPath` of rows to process, log in, fetch the full current state (e.g. all projects) once, then loop per-CSV-row doing a lookup/match, an API mutation, and on failure append to an error collection that's exported to an `-errorLogPath` CSV at the end, with a final matched/total summary. See `AST-AddScmScanTags.ps1` for a representative example (and its companion `AST-AddScmScanTags.README.md` for the level of documentation expected for a nontrivial script).

**Pagination:** `support/rest/cxone/getprojects.ps1` pages through `/api/projects` using `limit`/`offset` by default; pass `-UsePagination:$false` for the legacy single-call behavior (`limit=12000`). See `examples/getprojects-pagination-example.ps1`.
