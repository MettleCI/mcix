# 🚀 MCIX for IBM DataStage

**Static Code Analysis • Automated Unit Testing • CI/CD for IBM DataStage**

MCIX is a command-line toolkit that brings **modern engineering practices** to IBM DataStage NextGen.
It provides:

* **Automated static code analysis**
* **Dynamic unit testing**
* **Static analysis of flow designs**
* **Quality gates for your CI/CD pipelines**
* **Fully scriptable CLI for DevOps automation**

This repository exposes MCIX as a set of **GitHub Actions** so DataStage teams can run automated 
quality checks and deployment activities directly inside GitHub workflows.

---

## 🔧 Features

✅ Introduce DataStage teams to modern CI/CD practices<br>
✅ Run MCIX tests as part of continuous integration <br>
✅ Fail builds automatically on quality rule violations<br>
✅ Upload test results as workflow artifacts<br>
✅ Authenticate securely using GitHub Secrets<br>
✅ Integrate with GitHub seamlessly using native Actions<br>
✅ Run MCIX on GitHub cloud infrastructure<br>
✅ Repeatable static analysis of DataStage assets<br>
✅ Zero-configuration default scans — or fully custom rulesets

---

# 📦 Using These Actions in Your Workflow

```yaml
name: Validate DataStage Project

on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  mcix-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run MCIX static analysis
        uses: DataMigrators/mcix@v1
        with:
          api-key: ${{ secrets.MCIX_API_KEY }}
          url: https://your-mcix-server/api
          user: datastage.dev
          report: static-analysis
          project: MyDataStageProject
```

This runs MCIX against your DataStage project every time someone pushes or opens a pull request.

---

# ⚙️ Inputs

| Name         | Required | Description                                                                  |
| ------------ | -------- | ---------------------------------------------------------------------------- |
| `api-key`    | ✅        | API key for authentication to your MCIX server                               |
| `url`        | ✅        | Base URL of your MCIX server (e.g., `https://mcix.example.com/api`)          |
| `user`       | ✅        | Logical user identity used for audit & tagging                               |
| `report`     | ✅        | The MCIX report or test suite to run (e.g., `static-analysis`, `unit-tests`) |
| `project`    | ❓        | Name of the DataStage project to analyse                                     |
| `project-id` | ❓        | MCIX internal project ID (mutually exclusive with `project`)                 |

> **Note:** One of `project` and `project-id` must be provided, but not both.

---

# 📤 Outputs

The action exposes the following outputs:

| Output   | Description                                          |
| -------- | ---------------------------------------------------- |
| `result` | The textual result of the MCIX analysis              |
| `status` | `success` or `fail` depending on quality gate result |

Use them in your workflow like:

```yaml
      - name: Check MCIX Result
        run: echo "MCIX Status: ${{ steps.mcix.outputs.status }}"
```

---

# 🚨 Failure Conditions

The action will exit non-zero if:

* Static analysis detects violations exceeding your thresholds
* Unit tests fail
* MCIX cannot authenticate
* A report name is invalid
* Both `project` and `project-id` are provided

This ensures CI/CD pipelines fail fast and enforce DataStage quality.

---

# 📚 Documentation

Full documentation lives at:

👉 [https://docs.mettleci.io](https://docs.mettleci.io)
👉 [https://www.mettleci.com](https://www.mettleci.com)

Topics include:

* Installing and configuring MCIX
* Static analysis rules
* Writing DataStage unit tests
* CI/CD integration patterns
* Server configuration and security
* Example pipelines (GitHub & Jenkins)

---

# 🧪 Local Testing

To test MCIX locally:

```<TBC>```

---

# 🤝 Support

* Issues: [https://github.com/DataMigrators/mcix/issues](https://github.com/DataMigrators/mcix/issues)
* MettleCI Product Support: [https://support.mettleci.io](https://support.mettleci.io)
* Professional services & consulting: [https://datamigrators.com](https://datamigrators.com)

---

# 📝 License

This project is licensed under the **DataMigrators License Agreement**.
See the license file in the repository for details.

