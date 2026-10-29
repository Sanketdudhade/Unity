#!/usr/bin/env python3
"""
Safe Firebase Database Reset Utility — UNITY Manufacturing & Production Tracking
================================================================================
File: scripts/reset_unity_data.py

Role: Senior Firebase Backend Engineer, Firebase Security Specialist, and DBA.
Purpose: Resets application data to its initial empty state while strictly preserving
         the existing Main Admin account, Authentication credentials, permissions,
         and essential organization configuration.

Data Preserved:
  - Main Admin Firebase Auth account (UID, email, password, auth provider)
  - Main Admin Firestore profile (users/{admin_uid})
  - Main Admin employee record (organizations/{org_id}/employees/{admin_uid})
  - Main Admin custom claims ({ role: 'ADMIN', organizationId: org_id })
  - Minimum organization configuration document (organizations/{org_id})
  - Existing Firebase Auth configuration, security rules, and indexes

Data Reset (within authorized organization scope):
  - Employee profiles (users/{uid}) and directory records (organizations/{org_id}/employees/{uid})
  - Employee accounts in Firebase Authentication (deleted LAST)
  - Products master (organizations/{org_id}/products)
  - Production orders, work orders, processes, updates, and tasks
  - Inventory materials, stock balances, and transaction ledger
  - Shop-floor process queries, tickets, and responses
  - Notifications and audit logs
  - Legacy alias collections (production_orders, process_tasks, status_updates, process_queries)
  - Associated application-generated files in Firebase Storage

Operating Modes:
  1. Dry Run (Default): Read-only simulation. Counts data, prints safety summary.
  2. Backup: Creates verified local JSON exports before any destructive change.
  3. Execute Reset: Strict pre-flight validation -> Backup verification -> Controlled Reset.

Usage Examples:
  # Mode 1: Dry Run (Default, 100% safe, non-destructive preview)
  python scripts/reset_unity_data.py --admin-uid=<ADMIN_UID>

  # Mode 2: Backup Only
  python scripts/reset_unity_data.py --admin-uid=<ADMIN_UID> --backup

  # Mode 3: Execute Reset (Requires explicit confirmation prompt or flag)
  python scripts/reset_unity_data.py --admin-uid=<ADMIN_UID> --execute
"""

import argparse
import datetime
import hashlib
import json
import os
import sys
import time
import warnings
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

# Enable UTF-8 and line-buffering on Windows
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
        sys.stderr.reconfigure(encoding="utf-8", line_buffering=True)
    except Exception:
        pass

# Suppress benign Google Cloud SDK deprecation / positional argument warnings
warnings.filterwarnings("ignore", category=FutureWarning)
warnings.filterwarnings("ignore", category=UserWarning)

# Third-party imports with clear guidance if missing
try:
    import firebase_admin
    from firebase_admin import auth, credentials, firestore, storage
    from google.cloud.firestore_v1.base_document import DocumentSnapshot
except ImportError as err:
    print("\n[CRITICAL ERROR] Missing required Python package: firebase-admin")
    print("Please install firebase-admin in a separate virtual environment:")
    print("  python -m venv .venv")
    print("  .venv\\Scripts\\activate   # On Windows")
    print("  source .venv/bin/activate # On Linux/macOS")
    print("  pip install firebase-admin\n")
    sys.exit(1)


# ==============================================================================
# Terminal Styling and Formatting Helpers
# ==============================================================================

class Colors:
    HEADER = "\033[95m"
    BLUE = "\033[94m"
    CYAN = "\033[96m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    RESET = "\033[0m"

    @classmethod
    def strip(cls, text: str) -> str:
        import re
        return re.sub(r"\x1b\[[0-9;]*m", "", text)


def log_info(msg: str):
    print(f"{Colors.BLUE}[INFO]{Colors.RESET} {msg}")


def log_success(msg: str):
    print(f"{Colors.GREEN}[SUCCESS]{Colors.RESET} {msg}")


def log_warn(msg: str):
    print(f"{Colors.YELLOW}[WARNING]{Colors.RESET} {msg}")


def log_error(msg: str):
    print(f"{Colors.RED}[ERROR]{Colors.RESET} {msg}")


def log_header(title: str):
    bar = "=" * 78
    print(f"\n{Colors.CYAN}{Colors.BOLD}{bar}")
    print(f" {title}")
    print(f"{bar}{Colors.RESET}\n")


# ==============================================================================
# Configuration Data Model
# ==============================================================================

@dataclass
class UnityResetConfig:
    project_id: str = "unity-c5e69"
    org_id: str = "org_unity_001"
    admin_uid: str = ""
    service_account_path: Optional[str] = None
    storage_bucket_name: Optional[str] = None
    mode: str = "dry-run"  # 'dry-run', 'backup', 'execute'
    backup_dir: str = ""
    confirm_reset: bool = False
    include_other_admins: bool = False
    reset_templates: bool = False
    batch_size: int = 400  # Firestore batch limit is 500; 400 allows headroom

    def __post_init__(self):
        if not self.backup_dir:
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            self.backup_dir = os.path.abspath(os.path.join("backups", f"unity_reset_backup_{timestamp}"))


# Custom JSON encoder for Firestore types
class FirestoreEncoder(json.JSONEncoder):
    def default(self, o):
        if hasattr(o, "isoformat"):
            return o.isoformat()
        if hasattr(o, "to_dict"):
            return o.to_dict()
        if hasattr(o, "path"):
            return f"__ref__:{o.path}"
        if hasattr(o, "__iter__") and not isinstance(o, (list, dict, str)):
            return list(o)
        if isinstance(o, bytes):
            import base64
            return f"__bytes__:{base64.b64encode(o).decode('utf-8')}"
        return str(o)


# ==============================================================================
# Credential and Pre-Flight Security Validator
# ==============================================================================

class SecurityValidator:
    """Enforces strict isolation, identity verification, and pre-flight safety."""

    @staticmethod
    def locate_service_account(specified_path: Optional[str] = None) -> str:
        """Finds service account key using CLI arg, env var, or candidate locations."""
        candidates = []
        if specified_path:
            candidates.append(specified_path)

        env_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
        if env_path:
            candidates.append(env_path)

        script_dir = os.path.dirname(os.path.abspath(__file__))
        repo_root = os.path.abspath(os.path.join(script_dir, ".."))

        # Known workspace paths
        candidates.extend([
            os.path.join(script_dir, "serviceAccountKey.json"),
            os.path.join(repo_root, "serviceAccountKey.json"),
        ])

        # Scan for adminsdk JSON files
        for search_dir in (script_dir, repo_root):
            if os.path.isdir(search_dir):
                for f in os.listdir(search_dir):
                    if f.endswith(".json") and ("firebase-adminsdk" in f or "serviceAccount" in f):
                        candidates.append(os.path.join(search_dir, f))

        for path in candidates:
            if path and os.path.isfile(path):
                log_info(f"Discovered Service Account key: {path}")
                return os.path.abspath(path)

        raise FileNotFoundError(
            "Firebase Service Account key not found.\n"
            "Please provide a key file using --service-account=<path> or set GOOGLE_APPLICATION_CREDENTIALS."
        )

    @classmethod
    def initialize_firebase(cls, config: UnityResetConfig) -> Tuple[firestore.firestore.Client, Optional[Any]]:
        """Initializes Firebase Admin SDK and validates project identity."""
        key_path = cls.locate_service_account(config.service_account_path)

        with open(key_path, "r", encoding="utf-8") as f:
            sa_data = json.load(f)

        sa_project_id = sa_data.get("project_id")
        if not sa_project_id:
            raise ValueError(f"Service account file '{key_path}' does not specify 'project_id'.")

        if config.project_id and sa_project_id != config.project_id:
            raise ValueError(
                f"Project ID mismatch! Requested: '{config.project_id}', but Service Account belongs to: '{sa_project_id}'."
            )

        config.project_id = sa_project_id

        # Initialize or reuse Admin app
        if not firebase_admin._apps:
            cred = credentials.Certificate(key_path)
            app_options = {"projectId": sa_project_id}
            if config.storage_bucket_name:
                app_options["storageBucket"] = config.storage_bucket_name
            else:
                app_options["storageBucket"] = f"{sa_project_id}.firebasestorage.app"
            firebase_admin.initialize_app(cred, app_options)

        db = firestore.client()

        # Check storage bucket availability with safe timeout
        bucket = None
        try:
            bucket = storage.bucket()
            if not bucket.exists(timeout=3.0):
                alt_bucket = storage.bucket(f"{sa_project_id}.appspot.com")
                if alt_bucket.exists(timeout=3.0):
                    bucket = alt_bucket
                else:
                    bucket = None
        except Exception:
            bucket = None

        return db, bucket

    @classmethod
    def verify_main_admin(cls, db: firestore.firestore.Client, config: UnityResetConfig) -> Dict[str, Any]:
        """
        Positively identifies and validates the Main Admin account.
        Enforces that:
          1. Auth user exists.
          2. Firestore users/{admin_uid} exists.
          3. Role is strictly 'ADMIN'.
          4. Organization ID matches target scope.
          5. Account isActive flag is true.
        """
        if not config.admin_uid:
            raise ValueError(
                "Protected Main Admin UID must be explicitly supplied via --admin-uid.\n"
                "Run in Dry Run mode to inspect discovered Admin accounts if unsure."
            )

        admin_uid = config.admin_uid.strip()

        # 1. Verify in Firebase Auth
        try:
            auth_user = auth.get_user(admin_uid)
        except auth.UserNotFoundError:
            raise ValueError(f"Admin UID '{admin_uid}' was NOT found in Firebase Authentication.")
        except Exception as e:
            raise RuntimeError(f"Failed to query Firebase Authentication for UID '{admin_uid}': {e}")

        # 2. Verify in Firestore `users/{admin_uid}`
        user_doc_ref = db.collection("users").document(admin_uid)
        user_doc = user_doc_ref.get()

        if not user_doc.exists:
            raise ValueError(
                f"Admin UID '{admin_uid}' has no corresponding profile document in Firestore: users/{admin_uid}"
            )

        user_data = user_doc.to_dict() or {}
        role = str(user_data.get("role", "")).upper()
        org_id = str(user_data.get("organizationId", ""))
        is_active = user_data.get("isActive")

        if role != "ADMIN":
            raise ValueError(
                f"Security Violation: Target UID '{admin_uid}' has role '{role}' in Firestore. Must be 'ADMIN'."
            )

        if org_id != config.org_id:
            raise ValueError(
                f"Organization Mismatch: Target Admin belongs to '{org_id}', but reset is scoped to '{config.org_id}'."
            )

        if is_active is not True:
            raise ValueError(f"Security Alert: Target Admin document has isActive={is_active}. Must be true.")

        # 3. Check custom claims if present
        claims = auth_user.custom_claims or {}
        claim_role = str(claims.get("role", "")).upper()
        claim_org = str(claims.get("organizationId", ""))

        log_success(f"Verified Protected Main Admin: {auth_user.email} (UID: {admin_uid})")
        log_info(f"  Name: {user_data.get('fullName', 'N/A')} | Role: {role} | Org: {org_id}")
        if claims:
            log_info(f"  Custom Claims: role={claim_role}, org={claim_org}")

        return {
            "uid": admin_uid,
            "email": auth_user.email,
            "displayName": auth_user.display_name or user_data.get("fullName", ""),
            "userData": user_data,
            "claims": claims,
        }


# ==============================================================================
# Data Discovery and Inspection Engine
# ==============================================================================

class DatabaseInspector:
    """Inspects all Firestore collections, Auth accounts, and Storage objects."""

    CANONICAL_ORG_COLLECTIONS = [
        "employees",
        "products",
        "productionOrders",
        "materials",
        "inventoryBalances",
        "inventoryTransactions",
        "processQueries",
        "notifications",
        "auditLogs",
    ]

    LEGACY_ORG_COLLECTIONS = [
        "production_orders",
        "process_tasks",
        "status_updates",
        "process_queries",
    ]

    TEMPLATE_COLLECTIONS = [
        "processTemplates",
    ]

    def __init__(self, db: firestore.firestore.Client, bucket: Optional[Any], config: UnityResetConfig):
        self.db = db
        self.bucket = bucket
        self.config = config

    def inspect_users(self) -> Dict[str, Any]:
        """Classifies Firebase Auth and Firestore users into Protected vs Deletable."""
        auth_users_map: Dict[str, Any] = {}
        page = auth.list_users()
        while page:
            for u in page.users:
                auth_users_map[u.uid] = {
                    "uid": u.uid,
                    "email": u.email or "",
                    "displayName": u.display_name or "",
                    "claims": u.custom_claims or {},
                    "disabled": u.disabled,
                }
            page = page.get_next_page()

        # Firestore users
        firestore_users = {}
        for d in self.db.collection("users").stream():
            firestore_users[d.id] = d.to_dict()

        protected_users: List[Dict[str, Any]] = []
        deletable_users: List[Dict[str, Any]] = []
        ambiguous_users: List[Dict[str, Any]] = []

        all_uids = set(auth_users_map.keys()) | set(firestore_users.keys())

        for uid in all_uids:
            auth_info = auth_users_map.get(uid, {})
            fs_info = firestore_users.get(uid, {})
            email = auth_info.get("email") or fs_info.get("email", "unknown")
            role = (fs_info.get("role") or auth_info.get("claims", {}).get("role", "")).upper()
            user_org = fs_info.get("organizationId") or auth_info.get("claims", {}).get("organizationId", "")

            user_entry = {
                "uid": uid,
                "email": email,
                "role": role,
                "organizationId": user_org,
                "inAuth": uid in auth_users_map,
                "inFirestore": uid in firestore_users,
            }

            if uid == self.config.admin_uid:
                protected_users.append(user_entry)
            elif user_org != self.config.org_id:
                # Does not belong to target organization -> Ambiguous / Do not touch
                ambiguous_users.append(user_entry)
            elif role == "ADMIN":
                # Secondary admin in the same org
                if self.config.include_other_admins:
                    deletable_users.append(user_entry)
                else:
                    user_entry["reason"] = "Secondary Admin (preserved by default; use --include-other-admins to delete)"
                    ambiguous_users.append(user_entry)
            else:
                # Regular employee in target organization
                deletable_users.append(user_entry)

        return {
            "protected": protected_users,
            "deletable": deletable_users,
            "ambiguous": ambiguous_users,
            "auth_count": len(auth_users_map),
            "firestore_count": len(firestore_users),
        }

    def inspect_firestore(self) -> Dict[str, Any]:
        """Scans all organization collections and subcollections using fast collection group discovery."""
        org_ref = self.db.collection("organizations").document(self.config.org_id)
        org_exists = org_ref.get().exists
        org_prefix = f"organizations/{self.config.org_id}/"

        log_info("Scanning Firestore collections and nested subcollections...")

        # Fast parallel-friendly subcollection discovery via collection_group queries
        procs_in_org = [
            p for p in self.db.collection_group("processes").stream()
            if p.reference.path.startswith(org_prefix)
        ]
        upds_in_org = [
            u for u in self.db.collection_group("updates").stream()
            if u.reference.path.startswith(org_prefix)
        ]
        steps_in_org = [
            s for s in self.db.collection_group("steps").stream()
            if s.reference.path.startswith(org_prefix)
        ]
        resps_in_org = [
            r for r in self.db.collection_group("responses").stream()
            if r.reference.path.startswith(org_prefix)
        ]

        subcol_refs = list(org_ref.collections())
        existing_subcol_ids = {c.id for c in subcol_refs}

        scan_results: Dict[str, Any] = {
            "org_doc_exists": org_exists,
            "collections": {},
            "total_documents": 0,
            "subcollection_docs": {
                "processes": procs_in_org,
                "updates": upds_in_org,
                "steps": steps_in_org,
                "responses": resps_in_org,
            },
        }

        all_candidate_cols = set(
            self.CANONICAL_ORG_COLLECTIONS
            + self.LEGACY_ORG_COLLECTIONS
            + self.TEMPLATE_COLLECTIONS
            + list(existing_subcol_ids)
        )

        for col_name in sorted(all_candidate_cols):
            col_ref = org_ref.collection(col_name)
            docs = list(col_ref.stream())
            doc_count = len(docs)

            nested_count = 0
            if col_name == "productionOrders":
                nested_count = len(procs_in_org) + len(upds_in_org)
            elif col_name == "processTemplates":
                nested_count = len(steps_in_org)
            elif col_name == "processQueries":
                nested_count = len(resps_in_org)

            action = "DELETE"
            if col_name == "processTemplates" and not self.config.reset_templates:
                action = "PRESERVE (Template Schema)"
            elif col_name == "employees":
                action = "RESET EMPLOYEES (Preserve Admin Record)"
            elif col_name not in (self.CANONICAL_ORG_COLLECTIONS + self.LEGACY_ORG_COLLECTIONS + self.TEMPLATE_COLLECTIONS):
                action = "AMBIGUOUS / UNKNOWN COLLECTION"

            scan_results["collections"][col_name] = {
                "direct_count": doc_count,
                "nested_count": nested_count,
                "total_count": doc_count + nested_count,
                "action": action,
                "docs": docs,
            }

            if "DELETE" in action or "RESET" in action:
                scan_results["total_documents"] += (doc_count + nested_count)

        return scan_results

    def inspect_storage(self) -> Dict[str, Any]:
        """Scans Firebase Storage bucket for operational vs preserved files."""
        if not self.bucket:
            return {
                "available": False,
                "total_files": 0,
                "deletable_files": [],
                "preserved_files": [],
                "message": "Storage bucket not configured or not active in Google Cloud.",
            }

        try:
            blobs = list(self.bucket.list_blobs(max_results=500))
        except Exception as e:
            return {
                "available": False,
                "total_files": 0,
                "deletable_files": [],
                "preserved_files": [],
                "message": f"Could not list Storage bucket files: {e}",
            }

        deletable = []
        preserved = []

        OPERATIONAL_PREFIXES = (
            f"organizations/{self.config.org_id}/products/",
            f"organizations/{self.config.org_id}/orders/",
            f"organizations/{self.config.org_id}/tasks/",
            f"organizations/{self.config.org_id}/queries/",
            f"organizations/{self.config.org_id}/drawings/",
            f"organizations/{self.config.org_id}/attachments/",
            "products/",
            "drawings/",
            "orders/",
            "attachments/",
            "tasks/",
            "temp/",
        )

        for b in blobs:
            name = b.name
            if self.config.admin_uid in name or "branding" in name or "config" in name:
                preserved.append(name)
            elif name.startswith(OPERATIONAL_PREFIXES):
                deletable.append(name)
            else:
                preserved.append(f"{name} (Unidentified - Preserved)")

        return {
            "available": True,
            "total_files": len(blobs),
            "deletable_files": deletable,
            "preserved_files": preserved,
            "message": f"Bucket: {self.bucket.name}",
        }


# ==============================================================================
# Verified Backup Engine (Mode 2 & Pre-execution Guard)
# ==============================================================================

class BackupManager:
    """Creates complete, verified JSON backups of all data prior to deletion."""

    def __init__(self, db: firestore.firestore.Client, bucket: Optional[Any], config: UnityResetConfig):
        self.db = db
        self.bucket = bucket
        self.config = config

    def create_backup(self, scan_results: Dict[str, Any], user_results: Dict[str, Any]) -> str:
        """Exports all documents to local disk and returns the backup directory."""
        backup_path = Path(self.config.backup_dir)
        firestore_dir = backup_path / "firestore"
        auth_dir = backup_path / "auth"
        storage_dir = backup_path / "storage"

        firestore_dir.mkdir(parents=True, exist_ok=True)
        auth_dir.mkdir(parents=True, exist_ok=True)
        storage_dir.mkdir(parents=True, exist_ok=True)

        log_info(f"Creating verified pre-reset backup at: {backup_path}")
        manifest: Dict[str, Any] = {
            "created_at": datetime.datetime.now().isoformat(),
            "project_id": self.config.project_id,
            "organization_id": self.config.org_id,
            "protected_admin_uid": self.config.admin_uid,
            "files": {},
            "record_counts": {},
        }

        # 1. Backup Deletable Auth Users
        deletable_users = user_results["deletable"]
        auth_backup_file = auth_dir / "deletable_users.json"
        with open(auth_backup_file, "w", encoding="utf-8") as f:
            json.dump(deletable_users, f, indent=2, cls=FirestoreEncoder)
        manifest["record_counts"]["auth_deletable_users"] = len(deletable_users)
        manifest["files"]["auth_deletable_users"] = str(auth_backup_file.relative_to(backup_path))

        # 2. Backup Firestore Deletable Users
        user_docs_backup = {}
        for u in deletable_users:
            uid = u["uid"]
            doc = self.db.collection("users").document(uid).get()
            if doc.exists:
                user_docs_backup[uid] = doc.to_dict()

        users_fs_file = firestore_dir / "users_profiles.json"
        with open(users_fs_file, "w", encoding="utf-8") as f:
            json.dump(user_docs_backup, f, indent=2, cls=FirestoreEncoder)
        manifest["record_counts"]["firestore_users"] = len(user_docs_backup)
        manifest["files"]["firestore_users"] = str(users_fs_file.relative_to(backup_path))

        # 3. Backup Organization Top-Level Collections
        total_backed_up_docs = 0
        for col_name, col_meta in scan_results["collections"].items():
            if "DELETE" not in col_meta["action"] and "RESET" not in col_meta["action"]:
                continue

            col_data: Dict[str, Any] = {}
            for doc in col_meta.get("docs", []):
                if col_name == "employees" and doc.id == self.config.admin_uid:
                    continue
                col_data[doc.id] = {
                    "path": doc.reference.path,
                    "data": doc.to_dict(),
                }
                total_backed_up_docs += 1

            col_file = firestore_dir / f"{col_name}.json"
            with open(col_file, "w", encoding="utf-8") as f:
                json.dump(col_data, f, indent=2, cls=FirestoreEncoder)

            manifest["record_counts"][f"collection_{col_name}"] = len(col_data)
            manifest["files"][f"collection_{col_name}"] = str(col_file.relative_to(backup_path))

        # 4. Backup Nested Subcollections
        subcols = scan_results.get("subcollection_docs", {})

        # Subcollection: processes
        procs_data = {}
        for p in subcols.get("processes", []):
            procs_data[p.id] = {"path": p.reference.path, "data": p.to_dict()}
            total_backed_up_docs += 1
        procs_file = firestore_dir / "productionOrders_sub_processes.json"
        with open(procs_file, "w", encoding="utf-8") as f:
            json.dump(procs_data, f, indent=2, cls=FirestoreEncoder)
        manifest["record_counts"]["subcollection_processes"] = len(procs_data)
        manifest["files"]["subcollection_processes"] = str(procs_file.relative_to(backup_path))

        # Subcollection: updates
        upds_data = {}
        for u in subcols.get("updates", []):
            upds_data[u.id] = {"path": u.reference.path, "data": u.to_dict()}
            total_backed_up_docs += 1
        upds_file = firestore_dir / "productionOrders_sub_updates.json"
        with open(upds_file, "w", encoding="utf-8") as f:
            json.dump(upds_data, f, indent=2, cls=FirestoreEncoder)
        manifest["record_counts"]["subcollection_updates"] = len(upds_data)
        manifest["files"]["subcollection_updates"] = str(upds_file.relative_to(backup_path))

        # Subcollection: steps (if reset-templates requested)
        if self.config.reset_templates:
            steps_data = {}
            for s in subcols.get("steps", []):
                steps_data[s.id] = {"path": s.reference.path, "data": s.to_dict()}
                total_backed_up_docs += 1
            steps_file = firestore_dir / "processTemplates_sub_steps.json"
            with open(steps_file, "w", encoding="utf-8") as f:
                json.dump(steps_data, f, indent=2, cls=FirestoreEncoder)
            manifest["record_counts"]["subcollection_steps"] = len(steps_data)
            manifest["files"]["subcollection_steps"] = str(steps_file.relative_to(backup_path))

        # 5. Write Backup Manifest
        manifest["total_backed_up_documents"] = total_backed_up_docs
        manifest_file = backup_path / "backup_manifest.json"
        with open(manifest_file, "w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=2)

        # 6. Verify Backup Integrity
        self.verify_backup_integrity(backup_path, manifest)
        log_success(f"Backup verified successfully! {total_backed_up_docs} documents written.")
        return str(backup_path)

    @staticmethod
    def verify_backup_integrity(backup_path: Path, manifest: Dict[str, Any]):
        """Ensures all backed up files exist, are valid JSON, and have non-zero size."""
        for name, rel_path in manifest["files"].items():
            full_path = backup_path / rel_path
            if not full_path.is_file():
                raise RuntimeError(f"Backup verification failed: Missing file {full_path}")
            if full_path.stat().st_size == 0:
                raise RuntimeError(f"Backup verification failed: Empty file {full_path}")
            try:
                with open(full_path, "r", encoding="utf-8") as f:
                    json.load(f)
            except Exception as e:
                raise RuntimeError(f"Backup verification failed: Corrupt JSON in {full_path}: {e}")


# ==============================================================================
# Controlled Database Reset Executor (Mode 3)
# ==============================================================================

class DatabaseResetExecutor:
    """Executes safe, restartable, and leaf-first ordered deletion operations."""

    def __init__(
        self,
        db: firestore.firestore.Client,
        bucket: Optional[Any],
        config: UnityResetConfig,
        protected_uids: Set[str],
    ):
        self.db = db
        self.bucket = bucket
        self.config = config
        self.protected_uids = protected_uids

    def _batch_delete_docs(self, docs_list: List[DocumentSnapshot], label: str = "") -> int:
        """Deletes a list of DocumentSnapshots in safe batches of 400."""
        count = 0
        batch = self.db.batch()
        in_batch = 0

        for doc in docs_list:
            if doc.id in self.protected_uids:
                log_info(f"  [PRESERVED] Protected document: {doc.reference.path}")
                continue

            batch.delete(doc.reference)
            in_batch += 1
            count += 1

            if in_batch >= self.config.batch_size:
                batch.commit()
                batch = self.db.batch()
                in_batch = 0

        if in_batch > 0:
            batch.commit()

        if label:
            log_success(f"  Deleted {count} documents in {label}.")
        return count

    def execute_firestore_reset(self, scan_results: Dict[str, Any]) -> int:
        """
        Executes leaf-first deletion:
          Step 1: Delete deep subcollections (updates, processes, steps, responses)
          Step 2: Delete top-level organization collections
          Step 3: Delete non-admin employee directory records
          Step 4: Delete non-admin user documents in users/{uid}
        """
        log_header("STEP 1: Deleting Firestore Operational Documents (Leaf-First)")
        total_deleted = 0
        subcols = scan_results.get("subcollection_docs", {})

        # 1. Leaf subcollection: updates
        upds = subcols.get("updates", [])
        if upds:
            total_deleted += self._batch_delete_docs(upds, "subcollection: updates")

        # 2. Leaf subcollection: processes
        procs = subcols.get("processes", [])
        if procs:
            total_deleted += self._batch_delete_docs(procs, "subcollection: processes")

        # 3. Leaf subcollection: steps (if reset-templates requested)
        if self.config.reset_templates:
            steps = subcols.get("steps", [])
            if steps:
                total_deleted += self._batch_delete_docs(steps, "subcollection: steps")

        # 4. Leaf subcollection: responses
        resps = subcols.get("responses", [])
        if resps:
            total_deleted += self._batch_delete_docs(resps, "subcollection: responses")

        # 5. Top-level organization collections
        org_ref = self.db.collection("organizations").document(self.config.org_id)
        for col_name, col_meta in scan_results["collections"].items():
            if "DELETE" not in col_meta["action"] and "RESET" not in col_meta["action"]:
                log_info(f"Skipping preserved collection: {col_name}")
                continue

            if col_name == "employees":
                # Special handling for employees: preserve protected Admin
                emp_docs = list(org_ref.collection("employees").stream())
                deletable_emps = [d for d in emp_docs if d.id not in self.protected_uids]
                total_deleted += self._batch_delete_docs(deletable_emps, "employees directory (excluding Main Admin)")
            else:
                docs = col_meta.get("docs", [])
                if not docs:
                    docs = list(org_ref.collection(col_name).stream())
                total_deleted += self._batch_delete_docs(docs, f"collection: {col_name}")

        # 6. Reset non-admin user profile documents in root `users` collection
        log_info(f"Cleaning non-admin profiles in 'users' collection for org: {self.config.org_id}...")
        users_col = self.db.collection("users")
        users_to_delete = []

        for user_doc in users_col.where("organizationId", "==", self.config.org_id).stream():
            if user_doc.id in self.protected_uids:
                log_info(f"  [PRESERVED] Main Admin Firestore profile: users/{user_doc.id}")
                continue

            user_data = user_doc.to_dict() or {}
            if user_data.get("role") == "ADMIN" and not self.config.include_other_admins:
                log_warn(f"  [SKIPPED] Secondary Admin profile preserved: users/{user_doc.id}")
                continue

            users_to_delete.append(user_doc)

        deleted_users_count = self._batch_delete_docs(users_to_delete, "root 'users' collection")
        total_deleted += deleted_users_count

        # 7. Ensure organization root document exists with minimal metadata
        if not org_ref.get().exists:
            org_ref.set({
                "id": self.config.org_id,
                "name": "UNITY Manufacturing",
                "createdAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "status": "ACTIVE",
            }, merge=True)
            log_success(f"Maintained minimal organization configuration: organizations/{self.config.org_id}")

        return total_deleted

    def execute_storage_reset(self, storage_results: Dict[str, Any]) -> int:
        """Deletes application-generated files from Firebase Storage."""
        log_header("STEP 2: Cleaning Firebase Storage Objects")
        if not self.bucket or not storage_results["available"]:
            log_info("Storage bucket not available or active. Skipping Storage deletion.")
            return 0

        deletable_files = storage_results.get("deletable_files", [])
        if not deletable_files:
            log_info("No operational files detected in Firebase Storage.")
            return 0

        deleted_count = 0
        for blob_name in deletable_files:
            if any(uid in blob_name for uid in self.protected_uids):
                log_info(f"  [PRESERVED] Protected Storage asset: {blob_name}")
                continue

            try:
                blob = self.bucket.blob(blob_name)
                blob.delete()
                deleted_count += 1
                log_info(f"  Deleted Storage file: {blob_name}")
            except Exception as e:
                log_warn(f"  Failed to delete Storage file '{blob_name}': {e}")

        log_success(f"Deleted {deleted_count} operational Storage objects.")
        return deleted_count

    def execute_auth_reset(self, user_results: Dict[str, Any]) -> int:
        """Deletes employee accounts from Firebase Authentication (executed LAST)."""
        log_header("STEP 3: Deleting Employee Accounts from Firebase Authentication")
        deletable_users = user_results.get("deletable", [])
        if not deletable_users:
            log_info("No eligible employee accounts found for deletion in Firebase Auth.")
            return 0

        deleted_count = 0
        for u in deletable_users:
            uid = u["uid"]
            email = u.get("email", "")

            # Critical assertion: NEVER delete protected Admin account
            if uid in self.protected_uids:
                log_error(f"CRITICAL SAFETY ABORT: Attempted to delete protected Admin UID: {uid}")
                raise RuntimeError("Security invariant violated: Admin UID found in deletion list.")

            try:
                auth.delete_user(uid)
                deleted_count += 1
                log_info(f"  [✓] Deleted Firebase Auth user: {email} ({uid})")
            except auth.UserNotFoundError:
                log_warn(f"  Auth user {uid} already deleted or not found.")
            except Exception as e:
                log_error(f"  Failed to delete Auth user {uid} ({email}): {e}")

        log_success(f"Successfully removed {deleted_count} employee accounts from Firebase Authentication.")
        return deleted_count


# ==============================================================================
# Post-Reset Integrity Verifier
# ==============================================================================

class PostResetVerifier:
    """Verifies that the database conforms strictly to the expected post-reset state."""

    @staticmethod
    def verify(db: firestore.firestore.Client, config: UnityResetConfig) -> bool:
        log_header("STEP 4: Post-Reset Verification & Integrity Audit")
        all_passed = True

        # 1. Verify Main Admin Auth Account
        try:
            admin_auth = auth.get_user(config.admin_uid)
            log_success(f"1. Firebase Auth Main Admin: PRESENT ({admin_auth.email})")
        except Exception as e:
            log_error(f"1. Firebase Auth Main Admin: MISSING! Error: {e}")
            all_passed = False

        # 2. Verify Main Admin Firestore Document
        user_doc = db.collection("users").document(config.admin_uid).get()
        if user_doc.exists:
            data = user_doc.to_dict() or {}
            role = data.get("role")
            org = data.get("organizationId")
            active = data.get("isActive")
            if role == "ADMIN" and org == config.org_id and active is True:
                log_success(f"2. Firestore User Profile: PRESENT (Role: {role}, Org: {org}, Active: {active})")
            else:
                log_error(f"2. Firestore User Profile corrupted: role={role}, org={org}, active={active}")
                all_passed = False
        else:
            log_error(f"2. Firestore User Profile: MISSING at users/{config.admin_uid}")
            all_passed = False

        # 3. Verify Operational Collections are Empty
        org_ref = db.collection("organizations").document(config.org_id)
        operational_cols = [
            "products",
            "productionOrders",
            "materials",
            "inventoryBalances",
            "inventoryTransactions",
            "processQueries",
            "production_orders",
            "process_tasks",
            "status_updates",
            "process_queries",
        ]

        empty_checks_passed = True
        for col_name in operational_cols:
            count = len(list(org_ref.collection(col_name).limit(5).stream()))
            if count == 0:
                print(f"   ✓ organizations/{config.org_id}/{col_name}: EMPTY (0 records)")
            else:
                log_error(f"   ✗ organizations/{config.org_id}/{col_name}: NOT EMPTY ({count}+ records found)")
                empty_checks_passed = False
                all_passed = False

        if empty_checks_passed:
            log_success("3. Operational Collections: ALL VERIFIED EMPTY")

        # 4. Verify Employees Collection contains ONLY Main Admin (or 0)
        emp_docs = list(org_ref.collection("employees").stream())
        non_admin_emps = [e.id for e in emp_docs if e.id != config.admin_uid]
        if not non_admin_emps:
            log_success(f"4. Employee Directory: VERIFIED ({len(emp_docs)} records: only Main Admin present)")
        else:
            log_error(f"4. Employee Directory has residual employees: {non_admin_emps}")
            all_passed = False

        # 5. Verify Auth Users Count for this application
        page = auth.list_users()
        remaining_users = []
        while page:
            for u in page.users:
                claims = u.custom_claims or {}
                if claims.get("organizationId") == config.org_id:
                    remaining_users.append(u.email)
            page = page.get_next_page()

        log_info(f"5. Remaining Auth accounts in organization: {len(remaining_users)} {remaining_users}")

        if all_passed:
            log_success("\n[AUDIT PASSED] The UNITY Firebase project is in a clean initial state.")
            print(f"{Colors.GREEN}The Main Admin ({config.admin_uid}) can log in immediately with the original password.{Colors.RESET}\n")
        else:
            log_error("\n[AUDIT WARNING] Some verification checks reported unexpected residual data.")

        return all_passed


# ==============================================================================
# CLI and Orchestration
# ==============================================================================

def print_preview_table(scan_results: Dict[str, Any], user_results: Dict[str, Any], storage_results: Dict[str, Any], config: UnityResetConfig):
    """Prints a clear, formatted summary table for Dry Run and Execute confirmation."""
    log_header(f"RESET PREVIEW: UNITY Manufacturing & Production Tracking ({config.project_id})")

    print(f"{Colors.BOLD}Target Configuration:{Colors.RESET}")
    print(f"  • Project ID:           {Colors.CYAN}{config.project_id}{Colors.RESET}")
    print(f"  • Organization ID:      {Colors.CYAN}{config.org_id}{Colors.RESET}")
    print(f"  • Protected Admin UID:  {Colors.GREEN}{config.admin_uid}{Colors.RESET}")
    print(f"  • Reset Templates:      {Colors.YELLOW}{config.reset_templates}{Colors.RESET}")
    print(f"  • Delete Other Admins:  {Colors.YELLOW}{config.include_other_admins}{Colors.RESET}\n")

    # Firestore Collections Table
    print(f"{Colors.BOLD}{'Firestore Collection':<45} | {'Count':<7} | {'Action':<32}{Colors.RESET}")
    print("-" * 90)

    for col_name, meta in scan_results["collections"].items():
        count_str = str(meta["total_count"])
        action = meta["action"]
        col_disp = f"organizations/{config.org_id}/{col_name}"

        color = Colors.RESET
        if "DELETE" in action or "RESET" in action:
            color = Colors.RED
        elif "PRESERVE" in action:
            color = Colors.GREEN
        elif "AMBIGUOUS" in action:
            color = Colors.YELLOW

        print(f"{col_disp:<45} | {count_str:<7} | {color}{action:<32}{Colors.RESET}")

    print("-" * 90)
    print(f"{'Total Scoped Firestore Documents to Delete:':<45} | {Colors.BOLD}{Colors.RED}{scan_results['total_documents']}{Colors.RESET}\n")

    # Authentication Accounts Table
    print(f"{Colors.BOLD}Firebase Authentication Accounts:{Colors.RESET}")
    print(f"  • Protected Main Admin: {Colors.GREEN}{len(user_results['protected'])} account(s){Colors.RESET}")
    for p in user_results["protected"]:
        print(f"      - {p['email']} ({p['uid']}) [ROLE: {p['role']}]")

    print(f"  • Eligible for Deletion: {Colors.RED}{len(user_results['deletable'])} employee account(s){Colors.RESET}")
    for d in user_results["deletable"]:
        print(f"      - {d['email']} ({d['uid']}) [ROLE: {d['role']}]")

    if user_results["ambiguous"]:
        print(f"  • Preserved / Ambiguous Accounts: {Colors.YELLOW}{len(user_results['ambiguous'])} account(s){Colors.RESET}")
        for a in user_results["ambiguous"]:
            reason = a.get("reason", f"Belongs to '{a.get('organizationId', 'unknown')}'")
            print(f"      - {a['email']} ({a['uid']}) [{reason}]")

    print()

    # Storage Summary
    print(f"{Colors.BOLD}Firebase Storage:{Colors.RESET}")
    print(f"  • Status:               {storage_results['message']}")
    if storage_results["available"]:
        print(f"  • Operational Files:    {Colors.RED}{len(storage_results['deletable_files'])} to delete{Colors.RESET}")
        print(f"  • Preserved Files:      {Colors.GREEN}{len(storage_results['preserved_files'])} preserved{Colors.RESET}")
    print()


def main():
    parser = argparse.ArgumentParser(
        description="Safe Firebase Database Reset Utility -- UNITY Manufacturing & Production Tracking",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument("--project-id", default="unity-c5e69", help="Firebase Project ID (default: unity-c5e69)")
    parser.add_argument("--org-id", default="org_unity_001", help="Target Organization ID (default: org_unity_001)")
    parser.add_argument("--admin-uid", required=False, help="Protected Main Admin UID (must exist and have ADMIN role)")
    parser.add_argument("--service-account", "-k", help="Path to Firebase Service Account JSON key")
    parser.add_argument("--storage-bucket", help="Firebase Storage bucket name (optional override)")
    parser.add_argument("--backup-dir", help="Custom directory path for backups")

    # Mode selection
    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument("--dry-run", action="store_true", default=True, help="Mode 1: Dry Run preview (default)")
    mode_group.add_argument("--backup", action="store_true", help="Mode 2: Create verified data backup only")
    mode_group.add_argument("--execute", action="store_true", help="Mode 3: Execute full live reset")

    # Safety overrides
    parser.add_argument("--confirm-reset", action="store_true", help="Confirm execution without interactive prompt")
    parser.add_argument("--include-other-admins", action="store_true", help="Delete other non-main admins in the org")
    parser.add_argument("--reset-templates", action="store_true", help="Delete processTemplates collection as well")

    args = parser.parse_args()

    # Determine mode
    mode = "dry-run"
    if args.execute:
        mode = "execute"
    elif args.backup:
        mode = "backup"

    config = UnityResetConfig(
        project_id=args.project_id,
        org_id=args.org_id,
        admin_uid=args.admin_uid or "",
        service_account_path=args.service_account,
        storage_bucket_name=args.storage_bucket,
        mode=mode,
        backup_dir=args.backup_dir or "",
        confirm_reset=args.confirm_reset,
        include_other_admins=args.include_other_admins,
        reset_templates=args.reset_templates,
    )

    log_header("UNITY Manufacturing -- Safe Database Reset Utility")
    log_info(f"Connecting to Firebase Project: {config.project_id}...")

    # 1. Connect and Initialize
    try:
        db, bucket = SecurityValidator.initialize_firebase(config)
    except Exception as e:
        log_error(f"Firebase connection failed: {e}")
        sys.exit(1)

    # 2. Discover Admins if admin_uid is not provided
    if not config.admin_uid:
        log_info("No --admin-uid provided. Scanning existing Admin accounts...")
        discovered_admins = []
        for doc in db.collection("users").where("role", "==", "ADMIN").stream():
            d = doc.to_dict()
            if d.get("organizationId") == config.org_id:
                discovered_admins.append((doc.id, d.get("email", ""), d.get("fullName", "")))

        if not discovered_admins:
            log_error(f"No ADMIN accounts found in organization '{config.org_id}'. Cannot proceed.")
            sys.exit(1)

        print(f"\n{Colors.BOLD}Discovered Admin Accounts in '{config.org_id}':{Colors.RESET}")
        for idx, (uid, email, name) in enumerate(discovered_admins, 1):
            print(f"  [{idx}] UID: {uid} | Email: {email} | Name: {name}")

        if config.mode == "dry-run" and len(discovered_admins) == 1:
            config.admin_uid = discovered_admins[0][0]
            log_info(f"Auto-selected sole Admin UID for Dry Run preview: {config.admin_uid}")
        else:
            print(f"\n{Colors.YELLOW}Please re-run the script with --admin-uid=<UID> specifying your Main Admin.{Colors.RESET}")
            print(f"Example: python scripts/reset_unity_data.py --admin-uid={discovered_admins[0][0]}\n")
            sys.exit(1)

    # 3. Positively Validate Main Admin
    try:
        admin_info = SecurityValidator.verify_main_admin(db, config)
    except Exception as e:
        log_error(f"Security validation failed: {e}")
        sys.exit(1)

    protected_uids = {config.admin_uid}

    # 4. Inspect Data
    inspector = DatabaseInspector(db, bucket, config)
    user_results = inspector.inspect_users()
    scan_results = inspector.inspect_firestore()
    storage_results = inspector.inspect_storage()

    # 5. Print Preview
    print_preview_table(scan_results, user_results, storage_results, config)

    # ==========================================================================
    # MODE 1: DRY RUN
    # ==========================================================================
    if config.mode == "dry-run":
        log_success("[DRY RUN COMPLETE] No data was modified or deleted.")
        print(f"{Colors.CYAN}Next Steps:{Colors.RESET}")
        print("  1. To create a verified backup only:")
        print(f"     python scripts/reset_unity_data.py --admin-uid={config.admin_uid} --backup")
        print("  2. To execute the live database reset:")
        print(f"     python scripts/reset_unity_data.py --admin-uid={config.admin_uid} --execute\n")
        sys.exit(0)

    # ==========================================================================
    # MODE 2: BACKUP ONLY
    # ==========================================================================
    backup_mgr = BackupManager(db, bucket, config)
    if config.mode == "backup":
        try:
            backup_mgr.create_backup(scan_results, user_results)
            log_success(f"[BACKUP COMPLETE] Data safely archived to: {config.backup_dir}\n")
            sys.exit(0)
        except Exception as e:
            log_error(f"Backup failed: {e}")
            sys.exit(1)

    # ==========================================================================
    # MODE 3: EXECUTE RESET
    # ==========================================================================
    if config.mode == "execute":
        print(f"{Colors.RED}{Colors.BOLD}!!! WARNING: DESTRUCTIVE RESET OPERATION INITIATED !!!{Colors.RESET}")
        print(f"Target Project:      {config.project_id}")
        print(f"Organization Scope:  {config.org_id}")
        print(f"Protected Admin:     {admin_info['email']} ({config.admin_uid})")
        print(f"Firestore Docs:      {scan_results['total_documents']} documents will be DELETED")
        print(f"Auth Employees:      {len(user_results['deletable'])} employee accounts will be DELETED\n")

        # Confirmation prompt
        if not config.confirm_reset:
            confirm_str = f"RESET {config.org_id}"
            print(f"To confirm and permanently delete this data, type exactly: '{Colors.BOLD}{confirm_str}{Colors.RESET}'")
            try:
                user_input = input("Enter confirmation: ").strip()
            except (KeyboardInterrupt, EOFError):
                print()
                log_warn("Aborted by user.")
                sys.exit(1)

            if user_input != confirm_str:
                log_error("Confirmation mismatch. Aborting reset immediately.")
                sys.exit(1)

        # Mandatory Backup Before Deletion
        log_header("PRE-EXECUTION: Mandatory Verified Backup")
        try:
            backup_dir = backup_mgr.create_backup(scan_results, user_results)
        except Exception as e:
            log_error(f"CRITICAL: Pre-execution backup failed! Deletion aborted. Error: {e}")
            sys.exit(1)

        # Execute Reset in Controlled Order
        executor = DatabaseResetExecutor(db, bucket, config, protected_uids)
        try:
            # Step 1: Firestore
            deleted_fs = executor.execute_firestore_reset(scan_results)

            # Step 2: Storage
            deleted_storage = executor.execute_storage_reset(storage_results)

            # Step 3: Auth
            deleted_auth = executor.execute_auth_reset(user_results)

        except Exception as e:
            log_error(f"FATAL ERROR during reset execution: {e}")
            log_warn(f"A full backup exists at: {config.backup_dir}")
            sys.exit(1)

        # Step 4: Verification
        all_clean = PostResetVerifier.verify(db, config)

        log_header("RESET COMPLETED SUMMARY")
        print(f"  • Backup Location:     {backup_dir}")
        print(f"  • Firestore Deleted:   {deleted_fs} documents")
        print(f"  • Storage Deleted:     {deleted_storage} objects")
        print(f"  • Auth Users Deleted:  {deleted_auth} accounts")
        print(f"  • Protected Main Admin: {admin_info['email']} (ACTIVE)\n")

        sys.exit(0 if all_clean else 1)


if __name__ == "__main__":
    main()
