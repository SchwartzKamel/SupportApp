#!/bin/zsh

# Build SupportHelper Package
#
#
# Copyright 2024 Root3 B.V. All rights reserved.
#
# This script will build the SupportHelper Package
#
# USAGE:
# - Make sure an Keychain profile is stored for notarytool
# - Export SupportHelper binary to pkguild folder
# - Navigate to folder: pkgbuild/payload
# - Run the script: /build_pkg.zsh TARGET_VERSION_HERE
#
# THE SOFTWARE IS PROVIDED BY ROOT3 B.V. "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
# EVENT SHALL ROOT3 B.V. BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
# IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# ------------------    edit the variables below this line    ------------------

# Exit on error
set -e

# App Name
app_name="SupportHelper"

# App Bundle Identifier
bundle_identifier="nl.root3.support.helper"

# App Version
version=$1

# Path to folder with payload
payload="payload"

# Path to folder with scripts
scripts="scripts"

# Path to Component plist
component_plist="SupportHelper-component.plist"

# Requirements plist
requirements_plist="requirements.plist"

# Distribution xml
distribution_xml="distribution.xml"

# Install location
install_location="/usr/local/bin"

# Developer ID Installer certificate from Keychain
signing_identity="Developer ID Installer: Root3 B.V. (98LJ4XBGYK)"

# Name of the Keychain profile used for notarytool
keychain_profile="Root3"

# ---------------------    do not edit below this line    ----------------------

# Exit when nu version is specified
if [[ -z ${version} ]]; then
    echo "No version specified, add version as argument when running this script"
    exit 1
fi

# Get the username of the currently logged in user
username=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')

# NFS Home Directory of user
nfs_home_directory=$(dscl . read /Users/${username} NFSHomeDirectory | awk '{print $2}')

# Create directory
mkdir -p "${nfs_home_directory}/Downloads/${app_name}_${version}"

# Build and export pkg to Downloads folder
pkgbuild --root "${payload}" \
    --scripts "${scripts}" \
    --install-location "${install_location}" \
    --identifier "${bundle_identifier}" \
    --version "${version}" \
    "${nfs_home_directory}/Downloads/${app_name}_${version}/${app_name}_component.pkg"

# Create basic Distribution file
# productbuild --synthesize \
#     --package "${nfs_home_directory}/Downloads/${app_name}_${version}/Support_component.pkg" \
#     --product "${requirements_plist}" \
#     "${nfs_home_directory}/Downloads/${app_name}_${version}/distribution.xml"

# Create distribution package to support InstallApplication MDM command
productbuild --distribution "${distribution_xml}" \
    --package-path "${nfs_home_directory}/Downloads/${app_name}_${version}/" \
    "${nfs_home_directory}/Downloads/${app_name}_${version}/${app_name} ${version}_dist.pkg"

# Sign package
productsign --sign "${signing_identity}" \
    "${nfs_home_directory}/Downloads/${app_name}_${version}/${app_name} ${version}_dist.pkg" \
    "${nfs_home_directory}/Downloads/${app_name}_${version}/${app_name} ${version}.pkg"

# Submit pkg to notarytool
xcrun notarytool submit "${nfs_home_directory}/Downloads/${app_name}_${version}/${app_name} ${version}.pkg" \
    --keychain-profile "${keychain_profile}" \
    --wait

# Staple the notarization ticket to the pkg
xcrun stapler staple "${nfs_home_directory}/Downloads/${app_name}_${version}/${app_name} ${version}.pkg"

# Check the notarization ticket validity
spctl --assess -vv --type install "${nfs_home_directory}/Downloads/${app_name}_${version}/${app_name} ${version}.pkg"
