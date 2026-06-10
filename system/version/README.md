# MCIX System Version GitHub Action

Reports the MCIX toolset version available in the container.

<!-- BEGIN MCIX-ACTION-DOCS -->
# MCIX System Version

> [!CAUTION]
> This action is provided as a **technology preview** which may change, break, or disappear at any point and without warning.

Retrieve details on the MCIX container providing DataStage CI/CD capabilities for IBM Software Hub (Cloud Pak)

> Namespace: `system`<br>
> Action: `version`<br>
> Usage: `${{ github.repository }}/system/version@v1`

... where `v1` is the version of the action you wish to use.

---

## 🚀 Usage

Minimal example:

```yaml
jobs:
  system-version:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Run MCIX System Version
        id: system-version
        uses: ${{ github.repository }}/system/version@v1
        with:
          # container-registry: ghcr.io
          # image-name: mettleci/mcix
          # image-tag: latest
          # registry-user: <optional>
          # registry-api-key: <optional>
          # additional-args: <optional>
```

---

## 🔧 Inputs

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `container-registry` | ❌ | ghcr.io | The path of the container registry, eg "icr.io" |
| `image-name` | ❌ | mettleci/mcix | The namespace and name of the MCIX container image providing this task |
| `image-tag` | ❌ | latest | The tag of the MCIX container image providing this task |
| `registry-user` | ❌ |  | Username for sourcing the image from a private container registry |
| `registry-api-key` | ❌ |  | API Key for sourcing the image from a private container registry |
| `additional-args` | ❌ |  | Additional raw arguments to append to the mcix command |

---

## 📤 Outputs

| Name | Description |
| --- | --- |
| `return-code` | The return code of the command |

---

## 🧱 Implementation details

- `runs.using`: `composite`

---

## 🧩 Notes

- The sections above are auto-generated from `action.yml`.
- To edit this documentation, update `action.yml` (name/description/inputs/outputs).
<!-- END MCIX-ACTION-DOCS -->
## 📚 More information

See https://nextgen.mettleci.io/mettleci-cli/system-namespace/#system-version
