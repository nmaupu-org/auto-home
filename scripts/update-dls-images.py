#!/usr/bin/env python3
"""
Script to check and update Docker images in DLS helm chart values files
Usage: python3 update-dls-images.py
"""

import requests
import yaml
import sys
import os
import re
import glob
from pathlib import Path
from urllib.parse import urlparse
from packaging import version
import time

class CustomYamlDumper(yaml.SafeDumper):
    def increase_indent(self, flow=False, indentless=False):
        return super().increase_indent(flow, False)

class DockerImageUpdater:
    def __init__(self):
        self.image_cache = {}  # Cache to avoid duplicate HTTP requests
        self.failed_images = []  # Track images that failed to check
        self.session = requests.Session()
        self.session.headers.update({'User-Agent': 'DLS-Image-Updater/1.0'})
        
        # Add GitHub authentication if available
        github_token = os.environ.get('GITHUB_TOKEN')
        if github_token:
            self.session.headers.update({'Authorization': f'Bearer {github_token}'})
            print("🔑 Using GitHub authentication")
        else:
            print("ℹ️  No GitHub token found (some GHCR images may require authentication)")
            print("   Set GITHUB_TOKEN environment variable if needed")
    
    def discover_dls_values_files(self):
        """Discover all values.yaml files in DLS deployments"""
        pattern = 'k8s/argocd/nas/deploy/dls/*/values.yaml'
        return glob.glob(pattern, recursive=True)
    
    def parse_images_from_values(self, values_file):
        """Extract all image definitions from a values.yaml file"""
        try:
            with open(values_file, 'r') as file:
                data = yaml.safe_load(file)
            
            images = {}
            self._extract_images_recursive(data, images, "")
            return images
            
        except Exception as e:
            print(f"❌ Error parsing {values_file}: {e}")
            return {}
    
    def _extract_images_recursive(self, obj, images, prefix=""):
        """Recursively extract image repository/tag pairs"""
        if isinstance(obj, dict):
            # Check for repository/tag pattern
            if 'repository' in obj and 'tag' in obj:
                repo = obj['repository']
                tag = obj['tag']
                # Clean tag (remove SHA256 if present)
                clean_tag = tag.split('@')[0] if '@' in str(tag) else str(tag)
                
                key = prefix.rstrip('.')
                if not key:
                    key = 'image'
                    
                images[key] = {
                    'repository': repo,
                    'tag': clean_tag,
                    'original_tag': tag
                }
            
            # Recurse into nested objects
            for k, v in obj.items():
                new_prefix = f"{prefix}.{k}" if prefix else k
                self._extract_images_recursive(v, images, new_prefix)
    
    def get_registry_info(self, repository):
        """Parse registry information from repository"""
        # Handle different registry formats
        if repository.startswith('ghcr.io/'):
            return {
                'type': 'ghcr',
                'registry': 'ghcr.io',
                'namespace': repository.split('/')[1],
                'image': repository.split('/')[2]
            }
        elif repository.startswith('docker.io/') or '/' in repository and not '.' in repository.split('/')[0]:
            # Docker Hub
            parts = repository.replace('docker.io/', '').split('/')
            return {
                'type': 'dockerhub',
                'registry': 'registry.hub.docker.com',
                'namespace': parts[0] if len(parts) > 1 else 'library',
                'image': parts[-1]
            }
        else:
            return {
                'type': 'unknown',
                'registry': repository.split('/')[0],
                'repository': repository
            }
    
    def get_latest_tag(self, repository):
        """Get the latest tag for a Docker image"""
        if repository in self.image_cache:
            return self.image_cache[repository]
        
        print(f"🔍 Checking {repository}...")
        
        registry_info = self.get_registry_info(repository)
        latest_tag = None
        
        try:
            if registry_info['type'] == 'ghcr':
                latest_tag = self._get_ghcr_latest_tag(registry_info)
            elif registry_info['type'] == 'dockerhub':
                latest_tag = self._get_dockerhub_latest_tag(registry_info)
            else:
                print(f"⚠️  Unsupported registry: {repository}")
                latest_tag = None
                
        except Exception as e:
            print(f"❌ Error checking {repository}: {e}")
            latest_tag = None
        
        # Track failed images for summary
        if latest_tag is None:
            self.failed_images.append(repository)
        
        # Cache the result
        self.image_cache[repository] = latest_tag
        time.sleep(0.1)  # Be nice to APIs
        
        return latest_tag
    
    def _get_ghcr_latest_tag(self, info):
        """Get latest tag from GitHub Container Registry"""
        # Try the public API first (no auth required)
        urls_to_try = [
            f"https://api.github.com/users/{info['namespace']}/packages/container/{info['image']}/versions",
            f"https://ghcr.io/v2/{info['namespace']}/{info['image']}/tags/list"
        ]
        
        for url in urls_to_try:
            try:
                print(f"   🔍 Trying: {url}")
                response = self.session.get(url, timeout=10)
                print(f"   📡 Response: {response.status_code}")
                
                if response.status_code == 200:
                    data = response.json()
                    
                    if 'github.com' in url:
                        # GitHub Packages API format
                        tags = []
                        for item in data:
                            if 'metadata' in item and 'container' in item['metadata']:
                                container_tags = item['metadata']['container'].get('tags', [])
                                tags.extend(container_tags)
                    else:
                        # GHCR registry API format
                        tags = data.get('tags', [])
                    
                    # Filter out non-version tags and sort
                    version_tags = []
                    for tag in tags:
                        if self._is_version_tag(tag):
                            version_tags.append(tag)
                    
                    print(f"   🏷️  Found {len(version_tags)} version tags: {version_tags[:5]}...")
                    
                    if version_tags:
                        # Sort by version
                        try:
                            version_tags.sort(key=lambda x: version.parse(x.lstrip('v')), reverse=True)
                            print(f"   ✅ Latest: {version_tags[0]}")
                            return version_tags[0]
                        except:
                            # Fallback to string sort
                            version_tags.sort(reverse=True)
                            print(f"   ✅ Latest (string sort): {version_tags[0]}")
                            return version_tags[0]
                else:
                    print(f"   ❌ HTTP {response.status_code}: {response.text[:100]}")
                    
            except requests.RequestException as e:
                print(f"   ❌ Request error: {e}")
            except Exception as e:
                print(f"   ❌ Parse error: {e}")
        
        # Try GitHub releases as fallback
        if info['namespace'] == 'home-operations':
            return self._get_github_release_tag(info)
        elif info['namespace'] == 'flaresolverr':
            # Special case for flaresolverr
            return self._get_github_release_tag_direct('FlareSolverr/FlareSolverr')
        
        return None
    
    def _get_dockerhub_latest_tag(self, info):
        """Get latest tag from Docker Hub"""
        url = f"https://registry.hub.docker.com/v2/repositories/{info['namespace']}/{info['image']}/tags"
        
        try:
            print(f"   🔍 Trying: {url}")
            response = self.session.get(url, timeout=10)
            print(f"   📡 Response: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                tags = [result['name'] for result in data.get('results', [])]
                
                print(f"   🏷️  Found {len(tags)} total tags")
                
                # Filter and sort version tags
                version_tags = []
                for tag in tags:
                    if self._is_version_tag(tag):
                        version_tags.append(tag)
                
                print(f"   🏷️  Found {len(version_tags)} version tags: {version_tags[:5]}...")
                
                if version_tags:
                    try:
                        version_tags.sort(key=lambda x: version.parse(x.lstrip('v')), reverse=True)
                        print(f"   ✅ Latest: {version_tags[0]}")
                        return version_tags[0]
                    except:
                        version_tags.sort(reverse=True)
                        print(f"   ✅ Latest (string sort): {version_tags[0]}")
                        return version_tags[0]
            else:
                print(f"   ❌ HTTP {response.status_code}: {response.text[:100]}")
                        
        except requests.RequestException as e:
            print(f"   ❌ Docker Hub API error: {e}")
        except Exception as e:
            print(f"   ❌ Parse error: {e}")
        
        return None
    
    def _get_github_release_tag(self, info):
        """Get latest release from GitHub (fallback for home-operations images)"""
        # Map container names to GitHub repo names
        repo_map = {
            'sonarr': 'Sonarr/Sonarr',
            'radarr': 'Radarr/Radarr', 
            'bazarr': 'morpheus65535/bazarr',
            'prowlarr': 'Prowlarr/Prowlarr',
            'prowlarr-develop': 'Prowlarr/Prowlarr',  # Use main repo for develop branch
            'sabnzbd': 'sabnzbd/sabnzbd',
            'exportarr': 'onedr0p/exportarr'
        }
        
        github_repo = repo_map.get(info['image'])
        if not github_repo:
            return None
            
        url = f"https://api.github.com/repos/{github_repo}/releases/latest"
        
        try:
            print(f"   🔍 Trying GitHub releases: {url}")
            response = self.session.get(url, timeout=10)
            print(f"   📡 Response: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                tag_name = data.get('tag_name', '')
                
                if tag_name and self._is_version_tag(tag_name):
                    print(f"   ✅ Latest from GitHub: {tag_name}")
                    return tag_name
                else:
                    print(f"   ⚠️  Tag not a version: {tag_name}")
            else:
                print(f"   ❌ GitHub API {response.status_code}")
                
        except Exception as e:
            print(f"   ❌ GitHub API error: {e}")
        
        return None
    
    def _get_github_release_tag_direct(self, github_repo):
        """Get latest release from GitHub directly"""
        url = f"https://api.github.com/repos/{github_repo}/releases/latest"
        
        try:
            print(f"   🔍 Trying GitHub releases: {url}")
            response = self.session.get(url, timeout=10)
            print(f"   📡 Response: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                tag_name = data.get('tag_name', '')
                
                if tag_name and self._is_version_tag(tag_name):
                    print(f"   ✅ Latest from GitHub: {tag_name}")
                    return tag_name
                else:
                    print(f"   ⚠️  Tag not a version: {tag_name}")
            else:
                print(f"   ❌ GitHub API {response.status_code}")
                
        except Exception as e:
            print(f"   ❌ GitHub API error: {e}")
        
        return None
    
    def _is_version_tag(self, tag):
        """Check if a tag looks like a version number"""
        # Skip tags like 'latest', 'develop', 'main', etc.
        skip_tags = {'latest', 'develop', 'main', 'master', 'edge', 'nightly', 'beta', 'alpha'}
        if tag.lower() in skip_tags:
            return False
        
        # Look for version patterns (numbers with dots, or v prefix)
        version_pattern = re.compile(r'^v?\d+(\.\d+)*(\.\d+)*(-.*)?$')
        return bool(version_pattern.match(tag))
    
    def update_values_file(self, values_file, image_updates):
        """Update a values.yaml file with new image versions (preserving formatting)"""
        try:
            # Read the file as text to preserve formatting
            with open(values_file, 'r') as file:
                content = file.read()
            
            original_content = content
            
            # Parse YAML to understand structure
            data = yaml.safe_load(content)
            
            # Update each image using surgical string replacement
            for image_key, update_info in image_updates.items():
                content = self._update_tag_in_content(content, data, image_key, update_info)
            
            # Only write if content actually changed
            if content != original_content:
                with open(values_file, 'w') as file:
                    file.write(content)
                return True
            
        except Exception as e:
            print(f"❌ Error updating {values_file}: {e}")
        
        return False
    
    def _update_tag_in_content(self, content, data, image_key, update_info):
        """Update tag in content using surgical string replacement"""
        old_tag = update_info['current_tag']
        new_tag = update_info['new_tag']
        
        # Create patterns to match the specific tag line
        if image_key == 'image':
            # Match:   tag: old_value
            pattern = rf'^(\s*tag:\s*){re.escape(str(old_tag))}(\s*(?:#.*)?)\s*$'
        else:
            # For other images, we need to find the right section
            # This is more complex - let's find the image block first
            image_section_pattern = rf'^{re.escape(image_key)}:\s*$'
            lines = content.split('\n')
            
            # Find the image section
            image_section_start = -1
            for i, line in enumerate(lines):
                if re.match(image_section_pattern, line):
                    image_section_start = i
                    break
            
            if image_section_start == -1:
                print(f"   ⚠️  Could not find {image_key} section")
                return content
            
            # Find the tag line within the next few lines (with proper indentation)
            for i in range(image_section_start + 1, min(len(lines), image_section_start + 10)):
                line = lines[i]
                # Check if this line has the tag and matches our old tag
                tag_match = re.match(rf'^(\s*tag:\s*){re.escape(str(old_tag))}(\s*(?:#.*)?)\s*$', line)
                if tag_match:
                    # Replace just this line
                    lines[i] = f"{tag_match.group(1)}{new_tag}{tag_match.group(2) if tag_match.group(2) else ''}"
                    print(f"   Updated {image_key}.tag: {old_tag} → {new_tag}")
                    return '\n'.join(lines)
            
            print(f"   ⚠️  Could not find tag line for {image_key}")
            return content
        
        # For main image, use simple regex replacement
        replacement = rf'\g<1>{new_tag}\g<2>'
        new_content, count = re.subn(pattern, replacement, content, flags=re.MULTILINE)
        
        if count > 0:
            print(f"   Updated {image_key}.tag: {old_tag} → {new_tag}")
            return new_content
        else:
            print(f"   ⚠️  Could not find tag pattern for {image_key}")
            return content
    
    def _show_failed_images_summary(self):
        """Show summary of images that failed to check"""
        if not self.failed_images:
            return
            
        print(f"\n{'='*60}")
        print("⚠️  FAILED IMAGE CHECKS SUMMARY")
        print(f"{'='*60}")
        
        # Group failures by reason
        auth_failures = []
        other_failures = []
        
        for image in self.failed_images:
            if any(word in image.lower() for word in ['ghcr.io']):
                auth_failures.append(image)
            else:
                other_failures.append(image)
        
        if auth_failures:
            print(f"\n🔐 AUTHENTICATION REQUIRED ({len(auth_failures)}):")
            print("These GHCR images require authentication to check:")
            for image in auth_failures:
                print(f"   • {image}")
            
            print(f"\n💡 To fix GHCR authentication issues:")
            print(f"   1. Generate a GitHub Personal Access Token with 'read:packages' scope")
            print(f"   2. Set environment variable: export GITHUB_TOKEN=your_token")
            print(f"   3. Or use GitHub CLI: gh auth login")
        
        if other_failures:
            print(f"\n❌ OTHER FAILURES ({len(other_failures)}):")
            for image in other_failures:
                print(f"   • {image}")
        
        print(f"\n📊 Total: {len(self.failed_images)} images could not be checked")
    
    def run(self):
        """Main execution function"""
        print("🐳 DLS Docker Image Updater")
        print("=" * 60)
        
        # Check if we're in the right directory
        if not os.path.exists('k8s/argocd/nas/deploy/dls'):
            print("❌ Error: Please run this script from the auto-home repository root")
            sys.exit(1)
        
        # Discover values files
        values_files = self.discover_dls_values_files()
        
        if not values_files:
            print("❌ No values.yaml files found in DLS directory!")
            sys.exit(1)
        
        print(f"📋 Found {len(values_files)} values files to check")
        
        total_updates = 0
        files_with_updates = []
        
        for values_file in sorted(values_files):
            app_name = Path(values_file).parent.name
            print(f"\n📦 Checking {app_name}...")
            print(f"   File: {values_file}")
            
            # Parse images from values file
            images = self.parse_images_from_values(values_file)
            
            if not images:
                print("   ⚠️  No images found (skipping)")
                continue
            
            # Skip if no main image
            if 'image' not in images:
                print("   ⚠️  No main image.repository/tag found (skipping)")
                continue
            
            print(f"   🖼️  Found {len(images)} image(s)")
            
            updates_available = {}
            
            for image_key, image_info in images.items():
                repository = image_info['repository']
                current_tag = image_info['tag']
                
                print(f"      {image_key}: {repository}:{current_tag}")
                
                # Check for latest tag
                latest_tag = self.get_latest_tag(repository)
                
                if latest_tag and latest_tag != current_tag:
                    print(f"      🔄 Update available: {current_tag} → {latest_tag}")
                    updates_available[image_key] = {
                        'current_tag': current_tag,
                        'new_tag': latest_tag,
                        'repository': repository
                    }
                    total_updates += 1
                elif latest_tag:
                    print(f"      ✅ Up to date: {current_tag}")
                else:
                    print(f"      ❓ Could not check: {current_tag}")
            
            # Ask for confirmation and update if needed
            if updates_available:
                files_with_updates.append((values_file, app_name, updates_available))
        
        # Summary and confirmation
        if files_with_updates:
            print(f"\n{'='*60}")
            print("📊 UPDATE SUMMARY")
            print(f"{'='*60}")
            
            for values_file, app_name, updates in files_with_updates:
                print(f"\n📦 {app_name}:")
                for image_key, update_info in updates.items():
                    print(f"   {image_key}: {update_info['current_tag']} → {update_info['new_tag']}")
            
            print(f"\n💡 Found {total_updates} image updates across {len(files_with_updates)} applications.")
            
            # Ask for confirmation
            while True:
                response = input("\n🔄 Do you want to apply these updates? (y/n): ").lower().strip()
                if response in ['y', 'yes']:
                    break
                elif response in ['n', 'no']:
                    print("🚫 Updates cancelled by user.")
                    return
                else:
                    print("Please answer 'y' or 'n'")
            
            # Apply updates
            print(f"\n{'='*60}")
            print("🚀 APPLYING UPDATES")
            print(f"{'='*60}")
            
            success_count = 0
            for values_file, app_name, updates in files_with_updates:
                print(f"\n📝 Updating {app_name}...")
                if self.update_values_file(values_file, updates):
                    print(f"   ✅ Successfully updated {values_file}")
                    success_count += 1
                else:
                    print(f"   ❌ Failed to update {values_file}")
            
            print(f"\n{'='*60}")
            print("📊 UPDATE RESULTS")
            print(f"{'='*60}")
            print(f"✅ Successfully updated: {success_count}/{len(files_with_updates)} files")
            
            if success_count > 0:
                print(f"\n💡 Next steps:")
                print(f"   1. Review the changes: git diff")
                print(f"   2. Test the applications locally if possible")
                print(f"   3. Commit: git add . && git commit -m 'Update DLS Docker images'")
                print(f"   4. Push to trigger ArgoCD sync: git push")
        else:
            print(f"\n🎉 All Docker images are up to date!")
        
        # Show summary of failed images
        self._show_failed_images_summary()

def test_single_image(repository):
    """Test function to debug a single image"""
    updater = DockerImageUpdater()
    print(f"🧪 Testing image: {repository}")
    
    registry_info = updater.get_registry_info(repository)
    print(f"📋 Registry info: {registry_info}")
    
    latest_tag = updater.get_latest_tag(repository)
    print(f"🏷️  Latest tag: {latest_tag}")
    
    return latest_tag

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        # Test mode - check a single image
        if len(sys.argv) > 2:
            test_single_image(sys.argv[2])
        else:
            # Test with a known image
            test_single_image("ghcr.io/home-operations/sonarr")
    else:
        # Normal mode
        updater = DockerImageUpdater()
        updater.run()
