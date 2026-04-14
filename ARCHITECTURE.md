  flowchart LR

  %% =========================
  %% Styles
  %% =========================
  classDef registry fill:#e8f1ff,stroke:#3b82f6,stroke-width:2px,color:#111;
  classDef image fill:#eefbf3,stroke:#22c55e,stroke-width:2px,color:#111;
  classDef runtime fill:#fff7e6,stroke:#f59e0b,stroke-width:2px,color:#111;
  classDef tooling fill:#f5ecff,stroke:#8b5cf6,stroke-width:2px,color:#111;
  classDef plugin fill:#ffffff,stroke:#6b7280,stroke-width:1px,color:#111;
  classDef command fill:#dcfce7,stroke:#16a34a,stroke-width:2px,color:#111;

  %% =========================
  %% GitHub environment
  %% =========================
  subgraph GH["GitHub Environment"]
      GHA["GitHub Actions"]

      subgraph GHCONT["MCIX container instance"]
          GHMCIX["mcix command"]
          GHP1["import"]
          GHP2["compile"]
          GHP3["overlay"]
          GHP4["static analysis"]
          GHP4["static analysis"]
      end
  end
  class GHA tooling
  class GHMCIX command
  class GHP1,GHP2,GHP3,GHP4 plugin
  class GHCONT runtime

  %% =========================
  %% Registry
  %% =========================
  subgraph REG["IBM Container Registry"]
      ICR["icr.io/cp.mcix<br/>MCIX Container Image"]

      %% Image internals
      subgraph IMG["MCIX Container Image"]
          MCIX["mcix command"]

          subgraph PLUGINS["MCIX command plugins"]
              P1["import"]
              P2["compile"]
              P3["overlay"]
              P4["deploy / test / other commands"]
          end
      end
      class MCIX command
      class P1,P2,P3,P4 plugin
      class IMG image

  end
  class ICR registry

  ICR -.-> MCIX
  MCIX --> P1
  MCIX --> P2
  MCIX --> P3
  MCIX --> P4

  %% =========================
  %% Azure DevOps environment
  %% =========================
  subgraph ADO["Azure DevOps Environment"]
      ADOT["Azure DevOps Tasks"]

      subgraph ADOCONT["MCIX container instance"]
          ADOMCIX["mcix command"]
          ADOP1["import"]
          ADOP2["compile"]
          ADOP3["overlay"]
          ADOP4["other plugins"]
      end
  end
  class ADOT tooling
  class ADOMCIX command
  class ADOP1,ADOP2,ADOP3,ADOP4 plugin
  class ADOCONT runtime

  %% =========================
  %% Distribution from registry
  %% =========================
  ICR -.-> GHA
  ICR -.-> ADOT

  %% =========================
  %% Tooling references into runtime
  %% =========================
  GHA --> GHMCIX
  GHMCIX --> GHP1
  GHMCIX --> GHP2
  GHMCIX --> GHP3
  GHMCIX --> GHP4

  ADOT --> ADOMCIX
  ADOMCIX --> ADOP1
  ADOMCIX --> ADOP2
  ADOMCIX --> ADOP3
  ADOMCIX --> ADOP4
