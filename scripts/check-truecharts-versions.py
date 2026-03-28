#!/usr/bin/env python3
"""
Script to check TrueCharts versions by fetching Chart.yaml files from GitHub
Usage: python3 check-truecharts-versions.py
"""

import requests
import yaml
import sys
import os
import socket
from pathlib import Path
import glob
import urllib3.util.connection as urllib3_cn

# Force IPv4 to avoid "Network is unreachable" when IPv6 routing is unavailable
def _allowed_gai_family_ipv4():
    return socket.AF_INET

urllib3_cn.allowed_gai_family = _allowed_gai_family_ipv4

class CustomYamlDumper(yaml.SafeDumper):
    def increase_indent(self, flow=False, indentless=False):
        return super().increase_indent(flow, False)

def discover_truecharts_apps():
    """Discover all TrueCharts applications in the ArgoCD deployments"""
    apps = {}

    # Charts to ignore
    ignored_charts = {'traefik', 'traefik-crds', 'cert-manager', 'cloudnative-pg'}

    # Search patterns for both nas and iot deployments (recursive)
    search_patterns = [
        'k8s/argocd/nas/deploy/**/application*.yaml',
        'k8s/argocd/iot/deploy/**/application*.yaml'
    ]

    for pattern in search_patterns:
        for app_file in glob.glob(pattern, recursive=True):
            try:
                with open(app_file, 'r') as file:
                    app_data = yaml.safe_load(file)

                # Check if this app uses TrueCharts
                sources = app_data.get('spec', {}).get('sources', [])
                for source in sources:
                    if source.get('repoURL') == 'oci.trueforge.org/truecharts':
                        chart_name = source.get('chart', 'unknown')
                        app_name = app_data.get('metadata', {}).get('name', 'unknown')

                        # Skip ignored charts
                        if chart_name in ignored_charts:
                            print(f"🚫 Ignoring {app_name} ({chart_name})")
                            break

                        apps[f"{app_name} ({chart_name})"] = {
                            'path': app_file,
                            'chart': chart_name,
                            'app_name': app_name
                        }
                        break

            except Exception as e:
                print(f"Warning: Could not parse {app_file}: {e}")

    return apps

def get_current_version(app_path):
    """Read the current version from the application.yaml file"""
    try:
        with open(app_path, 'r') as file:
            app_data = yaml.safe_load(file)

        # Navigate through the YAML structure to find targetRevision for TrueCharts source
        sources = app_data.get('spec', {}).get('sources', [])
        for source in sources:
            if (source.get('repoURL') == 'oci.trueforge.org/truecharts' and
                'chart' in source and 'targetRevision' in source):
                return source.get('targetRevision', 'Unknown')

        return 'Unknown'

    except FileNotFoundError:
        return 'File not found'
    except yaml.YAMLError as e:
        return f'YAML Error: {e}'
    except Exception as e:
        return f'Error: {e}'

def update_application_yaml(file_path, new_version):
    """Update the targetRevision in an application.yaml file"""
    try:
        with open(file_path, 'r') as file:
            content = file.read()

        # Read and modify the YAML
        with open(file_path, 'r') as file:
            app_data = yaml.safe_load(file)

        # Find and update the TrueCharts source
        sources = app_data.get('spec', {}).get('sources', [])
        for source in sources:
            if source.get('repoURL') == 'oci.trueforge.org/truecharts':
                old_version = source.get('targetRevision', 'Unknown')
                source['targetRevision'] = new_version.split(' ')[0]  # Remove directory suffix

                # Write back to file with proper formatting
                with open(file_path, 'w') as file:
                    yaml.dump(app_data, file,
                             Dumper=CustomYamlDumper,
                             default_flow_style=False,
                             allow_unicode=True,
                             sort_keys=False,
                             indent=2,
                             width=120,
                             default_style=None)

                return True, old_version

        return False, "TrueCharts source not found"

    except Exception as e:
        return False, f"Error: {e}"

def ask_user_confirmation(updates_available):
    """Ask user if they want to apply the updates"""
    if not updates_available:
        return False

    print(f"\n{'='*80}")
    print("🤔 UPDATE CONFIRMATION")
    print(f"{'='*80}")
    print(f"Found {len(updates_available)} applications that can be updated.")
    print("\nApplications to update:")
    for app, current, latest, path in sorted(updates_available):
        clean_latest = latest.split(' ')[0]  # Remove directory suffix for display
        print(f"  • {app}: {current} → {clean_latest}")

    print(f"\n💡 This will modify the targetRevision in the application.yaml files.")

    while True:
        response = input("\n🔄 Do you want to apply these updates? (y/n): ").lower().strip()
        if response in ['y', 'yes']:
            return True
        elif response in ['n', 'no']:
            return False
        else:
            print("Please answer 'y' or 'n'")

def apply_updates(updates_available):
    """Apply the updates to the application.yaml files"""
    success_count = 0
    error_count = 0

    print(f"\n{'='*80}")
    print("🚀 APPLYING UPDATES")
    print(f"{'='*80}")

    for app, current, latest, path in updates_available:
        print(f"\n📝 Updating {app}...")
        print(f"   File: {path}")
        print(f"   Change: {current} → {latest.split(' ')[0]}")

        success, message = update_application_yaml(path, latest)

        if success:
            print(f"   Status: ✅ SUCCESS")
            success_count += 1
        else:
            print(f"   Status: ❌ FAILED - {message}")
            error_count += 1

    print(f"\n{'='*80}")
    print("📊 UPDATE RESULTS")
    print(f"{'='*80}")
    print(f"✅ Successfully updated: {success_count}")
    print(f"❌ Failed to update: {error_count}")

    if success_count > 0:
        print(f"\n💡 Next steps:")
        print(f"   1. Review the changes: git diff")
        print(f"   2. Commit the changes: git add . && git commit -m 'Update TrueCharts applications'")
        print(f"   3. Push to trigger ArgoCD sync: git push")

    return success_count, error_count

def get_latest_version(app_name):
    """Fetch the latest version from TrueCharts GitHub repository"""
    # Try different chart directories
    directories = ['stable', 'library', 'incubator']

    for directory in directories:
        url = f"https://raw.githubusercontent.com/trueforge-org/truecharts/master/charts/{directory}/{app_name}/Chart.yaml"

        try:
            response = requests.get(url)
            if response.status_code == 200:
                chart_data = yaml.safe_load(response.text)
                version = chart_data.get('version', 'Unknown')
                return f"{version} ({directory})" if directory != 'stable' else version

        except requests.ConnectionError as c:
            print(c)
            exit(1)
        except (requests.RequestException, yaml.YAMLError):
            continue

    return 'Not Found'

def main():
    print("🔍 Discovering and checking TrueCharts versions...")
    print("=" * 80)

    # Check if we're in the right directory
    if not os.path.exists('k8s/argocd'):
        print("❌ Error: Please run this script from the auto-home repository root")
        sys.exit(1)

    # Discover all TrueCharts applications
    print("🔎 Discovering TrueCharts applications...")
    apps = discover_truecharts_apps()

    if not apps:
        print("❌ No TrueCharts applications found!")
        sys.exit(1)

    print(f"📱 Found {len(apps)} TrueCharts applications")
    print("=" * 80)

    updates_available = []
    errors = []
    up_to_date = []

    for app_key, app_info in apps.items():
        print(f"\n📦 {app_key}")
        print(f"   Path: {app_info['path']}")

        # Get current version from application.yaml
        current_version = get_current_version(app_info['path'])
        print(f"   Current: {current_version}")

        # Get latest version from TrueCharts
        latest_version = get_latest_version(app_info['chart'])
        print(f"   Latest:  {latest_version}")

        # Compare versions (clean latest version for comparison)
        clean_latest = latest_version.split(' ')[0] if ' ' in str(latest_version) else latest_version

        if 'Error' in str(current_version) or 'Error' in str(latest_version) or latest_version == 'Not Found':
            print(f"   Status:  ❌ ERROR CHECKING")
            errors.append((app_key, current_version, latest_version, app_info['path']))
        elif current_version == 'Unknown' or latest_version == 'Unknown':
            print(f"   Status:  ❓ UNKNOWN VERSION")
            errors.append((app_key, current_version, latest_version, app_info['path']))
        elif current_version != clean_latest:
            print(f"   Status:  🔄 UPDATE AVAILABLE")
            updates_available.append((app_key, current_version, latest_version, app_info['path']))
        else:
            print(f"   Status:  ✅ UP TO DATE")
            up_to_date.append(app_key)

    # Summary
    print("\n" + "=" * 80)
    print("📊 SUMMARY")
    print("=" * 80)

    if up_to_date:
        print(f"✅ UP TO DATE ({len(up_to_date)}):")
        for app in sorted(up_to_date):
            print(f"   • {app}")
        print()

    if updates_available:
        print(f"🔄 UPDATES AVAILABLE ({len(updates_available)}):")
        for app, current, latest, path in sorted(updates_available):
            clean_latest = latest.split(' ')[0]  # Remove directory suffix for display
            print(f"   • {app}: {current} → {clean_latest}")
            print(f"     File: {path}")
        print()

    if errors:
        print(f"❌ ERRORS ENCOUNTERED ({len(errors)}):")
        for app, current, latest, path in sorted(errors):
            print(f"   • {app}: Current={current}, Latest={latest}")
            print(f"     File: {path}")
        print()

    print(f"📈 Total: {len(apps)} apps | ✅ {len(up_to_date)} up-to-date | 🔄 {len(updates_available)} updates | ❌ {len(errors)} errors")

    # Ask user for confirmation and apply updates if requested
    if updates_available and ask_user_confirmation(updates_available):
        apply_updates(updates_available)
    elif updates_available:
        print(f"\n🚫 Updates cancelled by user.")
    else:
        print(f"\n🎉 All applications are up to date!")

if __name__ == "__main__":
    main()
