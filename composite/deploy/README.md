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

- `overlay/apply` [../../overlay/apply/](link)
- `datastage/import` [../../datastage/import/](link)
- `datastage/compile` [../../datastage/compile/](link)

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
