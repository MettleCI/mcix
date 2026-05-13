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

✔️ Introduce DataStage teams to modern CI/CD practices<br>
✔️ Run MCIX tests as part of continuous integration <br>
✔️ Fail builds automatically on quality rule violations<br>
✔️ Upload test results as workflow artifacts<br>
✔️ Authenticate securely using GitHub Secrets<br>
✔️ Integrate with GitHub seamlessly using native Actions<br>
✔️ Run MCIX on GitHub cloud infrastructure<br>
✔️ Repeatable static analysis of DataStage assets<br>
✔️ Zero-configuration default scans — or fully custom rulesets

---

# 📦 Using These Actions in Your Workflow

```yaml
name: Asset Analysis

on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  mcix-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Run MCIX static analysis
        uses: mettleci/mcix-asset-analysis-test@v1
        with:
          api-key: ${{ secrets.CP4DKEY }}
          url: "${{ vars.CP4DHOSTNAME }}" 
          user: ${{ vars.CP4DUSERNAME }}
          project: ${{ env.DatastageProject }}         
          report: "${{ github.workspace }}/somefile.xml"
          rules: "${{ github.workspace }}/analysis-rules"
          include-tags: ${{ inputs.IncludeTags }}
          exclude-tags: ${{ inputs.ExcludeTags }}
          ignore-test-failures: true
          include-asset-in-test-name: true
          test-suite: "${{ inputs.AnalysisSuite }}"
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

Full documentation lives at [https://docs.mettleci.io](https://docs.mettleci.io).

Topics include:

* Installing and configuring MCIX
* Static analysis rules
* Writing DataStage unit tests
* CI/CD integration patterns
* Server configuration and security
* Example pipelines (GitHub, Azure DevOps, and Jenkins)

---

# 🧪 Local Testing

The `mcix` command is made available in two ways: as a Docker image or as a standalone CLI tool compatible with Linux or macOS.
Both options provide the same functionality, so you can choose the one that best fits your needs and environment.

## Docker

The Docker image enables you to explore the capabilities of `mcix` without needing to install anything. The image is hosted on a selection of popular container registries:
  * IBM Container Registry: `docker pull us.icr.io/mettleci/mcix:latest`
  * Azure Container Registry: `docker pull mettleci.azurecr.io/mcix:latest`
  * GitHub Container Registry: `docker pull ghcr.io/mettleci/mcix:latest`
  * Docker Hub: `docker pull mettleci/mcix:latest`

The Docker image also underpins the various GitHub Actions in this repository, so using it locally allows you to closely mirror the execution environment of the actions.

### Running the command within the container

This repository is the home of the GitHub Actions that wrap the various MCIX commands, so for testing and exploration purposes you can run the same Docker image used by your GitHub-hosted pipelines.

Use 'docker run' to execute MCIX commands inside the container. This takes the form:

```bash
docker run --rm \
  -v "$PWD:/work" \
  -w /work \
  <image> \
  mcix <command> [args...]
```

For example:

```shell
  docker run --rm \
    -v "$PWD:/work" \
    -w /work \
    ghcr.io/mettleci/mcix:latest \
    mcix asset-analysis test \
      --url "$CP4D_URL" \
      --user "$CP4D_USER" \
      --apikey "$CP4D_APIKEY" \
      --project "MyProject" \
      --rules "/work/rules" \
      --report "/work/report.xml"
```

## Command Line

`mcix` is available as a CLI tool that you can install directly on your local or self-hosted environment.  The CLI tool is available for two platforms:

### Linux

The Linux variant is intended for production use cases. It canb be installed using the following command:

```curl -L https://mettleci.io/install.sh | sh```

### macOS

The macOS variant is intended for educational and development use cases. It can be installed using the Homebrew package manager with the following command:

```brew install mettleci/mcix/mcix```
  
---

# 🤝 Support

* Issues: [https://github.com/DataMigrators/mcix/issues](https://github.com/DataMigrators/mcix/issues)
* MettleCI Product Support: [https://support.mettleci.io](https://support.mettleci.io)
* Professional services & consulting: [https://datamigrators.com](https://datamigrators.com)

---

# 📝 License

This project is licensed under the **DataMigrators License Agreement**.
See the license file in the repository for details.

