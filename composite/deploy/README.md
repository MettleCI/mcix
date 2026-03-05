# MCIX DataStage Deploy Action

This composite GitHub Action performs a **full DataStage deployment** by orchestrating three existing MCIX actions in sequence:

1. **Apply overlays** to exported DataStage assets
2. **Import** the resulting assets into a DataStage project
3. **Compile** the project and emit a JUnit report

It is designed to be used from a workflow with a **job-level GitHub Environment**, allowing environment-specific configuration via repository / environment variables.

---

## What this action does

```
Assets → [Overlay Apply] → [DataStage Import] → [DataStage Compile] → JUnit Report
```

Internally, this action calls the following MCIX commands/actions in sequence:

- `overlay/apply` [link](../../overlay/apply/)
- `datastage/import` [link](../../datastage/import/)
- `datastage/compile` [link](../../datastage/compile/)

---

## Usage

### Minimal example

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: prod

    steps:
      - uses: actions/checkout@v4

      - name: Deploy DataStage assets
        uses: your-org/your-repo/composite/deploy@v1
        with:
          api-key: ${{ secrets.CP4DKEY }}
          url: ${{ vars.CP4DHOSTNAME }}
          user: ${{ vars.CP4DUSERNAME }}
          assets: dist/assets.zip
          overlay: overlays/prod
          project: MyDataStageProject
````

---

## Inputs

### Authentication (required)

| Input     | Description                               |
| --------- | ----------------------------------------- |
| `api-key` | API key used to authenticate to DataStage |
| `url`     | DataStage service URL                     |
| `user`    | Username for authentication               |

---

### Target project

Exactly **one** of the following must be provided:

| Input        | Description            |
| ------------ | ---------------------- |
| `project`    | DataStage project name |
| `project-id` | DataStage project ID   |

---

### Assets & overlays

| Input            | Required | Description                                                         |
| ---------------- | -------- | ------------------------------------------------------------------- |
| `assets`         | ✅        | Exported DataStage assets (zip or directory)                        |
| `overlay`        | ✅        | Directory containing overlay files                                  |
| `properties`     | ❌        | Properties file for value substitution                              |
| `overlay-output` | ❌        | Path for generated overlaid assets (default: derived automatically) |

---

### Compile options

| Input                        | Required | Default              | Description                             |
| ---------------------------- | -------- | -------------------- | --------------------------------------- |
| `report`                     | ❌        | `compile-report.xml` | Path to write the JUnit compile report  |
| `include-asset-in-test-name` | ❌        | empty                | Include asset names in JUnit test names |

---

## Outputs

| Output                | Description                            |
| --------------------- | -------------------------------------- |
| `overlay-assets`      | Path to the generated overlaid assets  |
| `import-return-code`  | Return code from the import step       |
| `compile-return-code` | Return code from the compile step      |
| `junit-path`          | Path to the generated JUnit XML report |

Example usage:

```yaml
- name: Upload JUnit report
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: datastage-junit
    path: ${{ steps.deploy.outputs.junit-path }}
```

---

## Environment configuration (recommended)

This action works best when used with **GitHub Environments**.

Define environment-specific values under:

```
Settings → Environments → <env> → Variables / Secrets
```

Example variables:

* `CP4DHOSTNAME`
* `CP4DUSERNAME`

Secrets:

* `CP4DKEY`

Bind the job to the environment:

```yaml
environment: prod
```

---

## Error handling

* The action **fails fast** if required inputs are missing (i.e. it fails on the first error encountered, without attempting to continue with subsequent steps)
* Overlay, import, and compile failures are surfaced in the job log and the step summary and/or workflow annotations
* The JUnit report is still emitted where possible

---

## Design notes

* This is a **composite action**, comprising multiple separate Docker actions
* All orchestration happens in `action.yml`
* Paths are normalized relative to `GITHUB_WORKSPACE`

---

## Repository layout

```
├── composite/
│   └── deploy/
├── datastage/
│   ├── compile/
│   └── import/
├── overlay/
│   └── apply/
```

---

## License

See repository license.

<!-- BEGIN MCIX-ACTION-DOCS -->
# MCIX DataStage Deploy

Invokes the Overlay, DataStageImport, and Compile actions for a DataStage project on IBM Software Hub (Cloud Pak)

> Namespace: `composite`<br>
> Action: `deploy`<br>
> Usage: `${{ github.repository }}/composite/deploy@v1`

... where `v1` is the version of the action you wish to use.

---

## 🚀 Usage

Minimal example:

```yaml
jobs:
  composite-deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Run MCIX DataStage Deploy
        id: composite-deploy
        uses: ${{ github.repository }}/composite/deploy@v1
        with:
          api-key: <required>
          url: <required>
          user: <required>
          assets: <required>
          overlays: <required>
          # project: <optional>
          # project-id: <optional>
          # properties: <optional>
          # output: <optional>
          # report: compile-report.xml
          # include-asset-in-test-name: false
```

---

### Project selection rules

- Provide **exactly one** of `project` or `project-id`.
- If both are supplied, the action should fail fast (ambiguous).

---

## 🔧 Inputs

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `api-key` | ✅ |  | API key for authentication |
| `url` | ✅ |  | URL of the DataStage server |
| `user` | ✅ |  | Username for authentication |
| `project` | ❌ |  | DataStage project name (required if project-id not set) |
| `project-id` | ❌ |  | DataStage project id (required if project not set) |
| `assets` | ✅ |  | Path to DataStage export zip file or directory (input assets) |
| `overlays` | ✅ |  | One or more overlay directories. Overlays are applied in the order specified.
Provide as comma- or newline-separated list.
Example:
  overlays: overlays/base, overlays/customer
  or
  overlays: \|
    overlays/base
    overlays/customer |
| `properties` | ❌ |  | Optional properties file with replacement values |
| `output` | ❌ |  | Zip file or directory to write updated assets (default: derived) |
| `report` | ❌ | compile-report.xml | Path to output the compile report |
| `include-asset-in-test-name` | ❌ | false (if omitted) | Include asset names in test names in the report? (true/false) |

---

## 📤 Outputs

| Name | Description |
| --- | --- |
| `overlay_output` | Path to the overlaid assets produced by overlay apply |
| `import-junit-path` | Path to the JUnit report produced by import |
| `compile-junit-path` | Path to the JUnit report produced by compile |
| `return-code` | Return code (0 if overlay, import, and compile commands succeeded, otherwise non-zero) |

---

## 🧱 Implementation details

- `runs.using`: `composite`

---

## 🧩 Notes

- The sections above are auto-generated from `action.yml`.
- To edit this documentation, update `action.yml` (name/description/inputs/outputs).
<!-- END MCIX-ACTION-DOCS -->
