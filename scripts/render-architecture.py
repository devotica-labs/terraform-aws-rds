#!/usr/bin/env python3
"""Render an RDS architecture diagram from a Terraform plan JSON.

Shows the RDS instance at the centre with edges to:
  - KMS key (encrypts storage)
  - Secrets Manager (managed master password)
  - CloudWatch Logs (log exports)
  - Enhanced monitoring IAM role
  - Performance Insights label
  - Parameter group (when custom)

Usage:
    python scripts/render-architecture.py <plan.json> <output-path-no-ext>
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.database import RDS
from diagrams.aws.general import General
from diagrams.aws.management import Cloudwatch
from diagrams.aws.security import IAMRole, KMS, SecretsManager


def load_resources(plan_path: Path) -> list[dict]:
    plan = json.loads(plan_path.read_text())
    root = plan.get("planned_values", {}).get("root_module", {})
    collected: list[dict] = []

    def walk(mod: dict) -> None:
        for r in mod.get("resources", []):
            collected.append(r)
        for child in mod.get("child_modules", []):
            walk(child)

    walk(root)
    return collected


def render(plan_path: Path, out_no_ext: Path) -> None:
    resources = load_resources(plan_path)

    instances = [r for r in resources if r["type"] == "aws_db_instance"]
    if not instances:
        raise SystemExit("No aws_db_instance resource found in plan — nothing to render.")

    inst_v = instances[0].get("values", {}) or {}
    identifier = inst_v.get("identifier") or "db"
    engine = inst_v.get("engine") or "?"
    engine_version = inst_v.get("engine_version") or ""
    instance_class = inst_v.get("instance_class") or ""
    multi_az = bool(inst_v.get("multi_az"))
    iam_db_auth = bool(inst_v.get("iam_database_authentication_enabled"))
    perf_insights = bool(inst_v.get("performance_insights_enabled"))
    storage_encrypted = bool(inst_v.get("storage_encrypted"))
    managed_pwd = bool(inst_v.get("manage_master_user_password"))
    log_exports = inst_v.get("enabled_cloudwatch_logs_exports") or []

    has_monitoring_role = any(r["type"] == "aws_iam_role" for r in resources)
    has_parameter_group = any(r["type"] == "aws_db_parameter_group" for r in resources)

    graph_attr = {
        "fontsize": "20",
        "splines": "ortho",
        "ranksep": "1.0",
        "nodesep": "0.5",
        "pad": "0.5",
    }

    badges = []
    if multi_az:
        badges.append("multi-AZ")
    if iam_db_auth:
        badges.append("IAM auth")
    if perf_insights:
        badges.append("PI on")
    title_badges = " · ".join(badges) if badges else "single-AZ"

    out_no_ext.parent.mkdir(parents=True, exist_ok=True)
    with Diagram(
        f"terraform-aws-rds — {identifier} ({engine} {engine_version}, {instance_class}) · {title_badges}",
        filename=str(out_no_ext),
        show=False,
        direction="LR",
        outformat="png",
        graph_attr=graph_attr,
    ):
        with Cluster(identifier):
            rds_node = RDS(f"{engine}\n{instance_class}")

            if storage_encrypted:
                KMS("KMS (storage)") >> Edge(label="encrypts", style="dashed") >> rds_node

            if managed_pwd:
                rds_node >> Edge(label="rotates", style="dotted") >> SecretsManager(
                    "Master password\n(AWS-managed)"
                )

            if log_exports:
                cw = Cloudwatch("\n".join(["CloudWatch Logs"] + log_exports))
                rds_node >> Edge(label="exports", style="dotted") >> cw

            if has_monitoring_role:
                role = IAMRole("Enhanced\nMonitoring Role")
                role >> Edge(label="assume", style="dashed") >> rds_node

            if has_parameter_group:
                General("Parameter\nGroup") >> Edge(style="dashed") >> rds_node


def main() -> None:
    if len(sys.argv) < 3:
        sys.stderr.write(
            "Usage: render-architecture.py <plan.json> <output-path-without-ext>\n"
        )
        sys.exit(2)
    render(Path(sys.argv[1]), Path(sys.argv[2]))


if __name__ == "__main__":
    main()
