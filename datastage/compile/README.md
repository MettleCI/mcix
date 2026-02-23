# MCIX DataStage Compile GitHub Action

Compile DataStage NextGen assets in a target project using **MCIX**, directly from your GitHub workflows.

This action wraps the `mcix datastage compile` command so you can automatically compile jobs/flows that have already been imported into a DataStage project as part of your CI/CD pipeline.

> Namespace: `datastage`
> Action: `compile`
> Usage: `DataMigrators/mcix/datastage/compile@v1`

... where `v1` is the version of the action you wish to use.

---

## 🚀 Usage

Minimal example:

```yaml
jobs:
  datastage-compile:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Compile DataStage assets with MCIX
        id: mcix-datastage-compile
        uses: DataMigrators/mcix/datastage/compile@v1
        with:
          api-key: ${{ secrets.MCIX_API_KEY }}
          url: https://your-mcix-server/api
          user: dm-automation

          # Identify the project (choose one)
          project: GitHub_CP4D_DevOps
          # OR:
          # project-id: b0e219f8-1a03-432f-972d-896cec55a862

          # Optional: report / profile name
          report: compile
````

---

## 🔧 Inputs

These map to the `mcix datastage compile` entrypoint:

| Name                         | Required | Description                                                              |
| ---------------------------- | -------- | ------------------------------------------------------------------------ |
| `api-key`                    | ✅        | API key for authenticating with the MCIX server                          |
| `url`                        | ✅        | Base URL of the MCIX / DataStage integration endpoint                    |
| `user`                       | ✅        | Logical user identity used for audit / tagging                           |
| `project`                    | ⚠️       | DataStage project name – required if `project-id` is not provided        |
| `project-id`                 | ⚠️       | DataStage project ID/UUID – required if `project` is not provided        |
| `report`                     | ❌        | Optional report/profile name (e.g. `compile`), if your CLI supports it   |
| `include-asset-in-test-name` | ❌        | Optional boolean flag; when `true`, passes `-include-asset-in-test-name` |

**Project selection rules**

The underlying script enforces:

* ✅ Exactly **one** of `project` or `project-id` must be provided
* ❌ It fails fast if **both** are provided
* ❌ It fails fast if **neither** is provided

---

## 📤 Outputs

Typical pattern (match your `action.yml` / `entrypoint.sh`):

```sh
echo "return-code=$status" >> "$GITHUB_OUTPUT"
```

So you’ll have:

| Name          | Description                                         |
| ------------- | --------------------------------------------------- |
| `return-code` | Exit code from the `mcix datastage compile` command |

Example usage:

```yaml
      - name: Check compile result
        run: echo "Compile exit code: ${{ steps.mcix-datastage-compile.outputs.return-code }}"
```

---

## 🧩 Example – Import then Compile

```yaml
jobs:
  import-and-compile:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Import DataStage assets
        id: import
        uses: DataMigrators/mcix/datastage/import@v1
        with:
          api-key: ${{ secrets.MCIX_API_KEY }}
          url: https://your-mcix-server/api
          user: dm-automation
          assets: ./datastage/assets
          project: GitHub_CP4D_DevOps

      - name: Compile DataStage assets
        id: compile
        uses: DataMigrators/mcix/datastage/compile@v1
        with:
          api-key: ${{ secrets.MCIX_API_KEY }}
          url: https://your-mcix-server/api
          user: dm-automation
          project: GitHub_CP4D_DevOps
          report: compile

      - name: Check compile result
        run: echo "Compile exit code: ${{ steps.compile.outputs.return-code }}"
```

---

## 📚 More information

See https://nextgen.mettleci.io/mettleci-cli/datastage-namespace/#datastage-compile

<!-- BEGIN MCIX-ACTION-DOCS -->
# MCIX datastage compile action

Runs mcix datastage compile

> Namespace: `datastage`<br>
> Action: `compile`<br>
> Usage: `${{ github.repository }}/datastage/compile@v1`

... where `v1` is the version of the action you wish to use.

---

## 🚀 Usage

Minimal example:

```yaml
jobs:
  datastage-compile:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Run MCIX datastage compile action
        id: datastage-compile
        uses: ${{ github.repository }}/datastage/compile@v1
        with:
          api-key: <required>
          url: <required>
          user: <required>
          # report: compile-report.xml
          # project: <optional>
          # project-id: <optional>
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
| `report` | ❌ | compile-report.xml | Path to output the compile report |
| `project` | ❌ |  | DataStage project name |
| `project-id` | ❌ |  | DataStage project id |
| `include-asset-in-test-name` | ❌ | false (if omitted) | Include asset names in test names in the report? (true/false) |

---

## 📤 Outputs

| Name | Description |
| --- | --- |
| `return-code` | The return code of the command |
| `junit-path` | Path to the JUnit report XML generated by mcix datastage compile |

---

## 🧱 Implementation details

- `runs.using`: `docker`
- `runs.image`: `Dockerfile`

---

## 🧩 Notes

- The sections above are auto-generated from `action.yml`.
- To edit this documentation, update `action.yml` (name/description/inputs/outputs).
<!-- END MCIX-ACTION-DOCS -->
