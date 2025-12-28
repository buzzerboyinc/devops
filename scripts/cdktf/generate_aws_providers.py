#!/usr/bin/env python3
import json
import subprocess
import os
import argparse

# -----------------------------
# Default configuration
# -----------------------------
DEFAULT_AWS_VERSION = "5.49.0"
PROVIDER_SOURCE = "hashicorp/aws"
GEN_PATH = ".gen/providers/aws"
SUBSET_FILE = "aws-provider-subset.json"

# Default AWS services
DEFAULT_AWS_SERVICES = [
    "lightsail",
    "secretsmanager",
    "iam"
]

# -----------------------------
# Argument parsing
# -----------------------------
parser = argparse.ArgumentParser(
    description="Generate a minimal AWS provider subset for CDKTF"
)
parser.add_argument(
    "--additional-services",
    type=str,
    help="Comma-separated list of additional AWS services to include",
    default=""
)
parser.add_argument(
    "--aws-version",
    type=str,
    help=f"AWS provider version to use (default: {DEFAULT_AWS_VERSION})",
    default=DEFAULT_AWS_VERSION
)
args = parser.parse_args()

# -----------------------------
# AWS services list
# -----------------------------
aws_services = DEFAULT_AWS_SERVICES.copy()

if args.additional_services:
    additional_services = [s.strip() for s in args.additional_services.split(",") if s.strip()]
    aws_services.extend(additional_services)
    print(f"🟢 Adding additional AWS services: {additional_services}")

# Deduplicate services just in case
aws_services = list(dict.fromkeys(aws_services))
print(f"ℹ️  Final AWS services list: {aws_services}")

# -----------------------------
# AWS version
# -----------------------------
aws_version = args.aws_version
print(f"ℹ️  Using AWS provider version: {aws_version}")

# -----------------------------
# Helper: generate wildcard names
# -----------------------------
def build_wildcards(services):
    return [f"aws_{service}_*" for service in services]

# -----------------------------
# Ensure output directories exist
# -----------------------------
os.makedirs(os.path.dirname(GEN_PATH), exist_ok=True)

# -----------------------------
# 1. Create subset definition
# -----------------------------
subset = {
    "resourceTypes": build_wildcards(aws_services),
    "dataSources": build_wildcards(aws_services)
}

with open(SUBSET_FILE, "w") as f:
    json.dump(subset, f, indent=2)
print(f"✅ Subset file created/updated at {SUBSET_FILE}")

# -----------------------------
# 2. Ensure cdktf-provider-generator is installed
# -----------------------------
try:
    subprocess.run(
        ["npx", "--yes", "cdktf/provider-generator", "--version"],
        check=True,
        capture_output=True
    )
except subprocess.CalledProcessError:
    print("📦 Installing @cdktf/provider-generator...")
    subprocess.run(["npm", "install", "--save-dev", "@cdktf/provider-generator"], check=True)

# -----------------------------
# 3. Generate provider subset
# -----------------------------
print("🚀 Generating AWS provider subset...")
subprocess.run([
    "npx", "cdktf/provider-generator",
    "--language=python",
    "--provider-name=aws",
    "--provider-source", PROVIDER_SOURCE,
    "--provider-version", aws_version,
    "--output-path", GEN_PATH,
    "--subset", SUBSET_FILE
], check=True)
# -----------------------------
# 4. Run cdktf get
# -----------------------------
print("⚙️  Running cdktf get...")
subprocess.run(["cdktf", "get", "--no-synth"], check=True)

print(f"✅ Done! Minimal AWS provider generated at {GEN_PATH}")
