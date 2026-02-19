# MCIX System Version GitHub Action

Reports the MCIX toolset version available in the container.

<!-- BEGIN MCIX-ACTION-DOCS -->
# MCIX system version action

Runs mcix system version

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
        uses: actions/checkout@v4

      - name: Run MCIX system version action
        id: system-version
        uses: ${{ github.repository }}/system/version@v1
```

---

## 📤 Outputs

| Name | Description |
| --- | --- |
| `return-code` | The return code of the command |

---

## 🧱 Implementation details

- `runs.using`: `docker`
- `runs.image`: `Dockerfile`

---

## 🧩 Notes

- The sections above are auto-generated from `action.yml`.
- To edit this documentation, update `action.yml` (name/description/inputs/outputs).
<!-- END MCIX-ACTION-DOCS -->
## 📚 More information

See https://nextgen.mettleci.io/mettleci-cli/system-namespace/#system-version
