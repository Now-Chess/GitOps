---
name: project-spark-cluster
description: Spark cluster deployment facts — chart version, service names, history server gap, hostname pattern
metadata:
  type: project
---

Bitnami Spark chart 9.2.10 (Spark 3.5.2) is pinned in `spark-cluster/base/kustomization.yaml`.

**Chart service names (rendered with releaseName=spark):**
- `spark-master-svc` — master Web UI on port 80 (targetPort: http/8080), cluster port 7077
- `spark-headless` — headless service for all nodes

**History server gap:** Chart 9.2.10 has NO standalone history server Deployment/Service. The `historyServer` chart key does not exist in this version. The `spark-history-ingress` in `spark-cluster/base/ingress.yaml` is a placeholder pointing to `spark-history-server-svc:18080` — this service does not exist until a separate Deployment is added.

**Why:** The Bitnami chart 9.2.10 only renders master + worker StatefulSets. A real history server requires either a newer chart version that adds it, or a hand-rolled Deployment.

**Hostnames:** `*.nowchess.janis-eccarius.de` — master UI at `spark.nowchess.janis-eccarius.de`, history at `spark-history.nowchess.janis-eccarius.de`. Ingress class: `traefik` (k3d default, different from production overlays which use `nginx`).

**Spark standalone mode:** All analytics CronJobs and the streaming Deployment use `spark://spark-master:7077` (not `k8s://https://kubernetes.default.svc:443`). Event logging enabled to `/spark-events` PVC (`spark-events`, RWO/local-path compatible).

**How to apply:** When working on Spark-related NCI tickets, check `spark-cluster/base/` for chart version and service names before writing ingress or spark-submit commands. If history server is needed, a new Deployment + Service named `spark-history-server-svc` on port 18080 must be added to the base.
