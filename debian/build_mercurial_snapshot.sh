#!/bin/sh

#
# build_mercurial_snapshot.sh
# 
# Licensed under the BSD License:
# 
# Copyright (c) 2014, Roberto C. Sanchez
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of 'Roberto C. Sanchez', 'Connexer Ltd.' nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY Roberto C. Sanchez ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL Evan Wies BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

for arg in "$@"; do
  if [ "$arg" = "-h" ]; then
    echo "Usage: ./debian/build_mercurial_snapshot.sh [options for mercurial-buildpackage]"
    echo ""
    echo "  This script is used to build a .deb package directly from a snapshot of the"
    echo "  current mercurial respository."
    echo ""
    echo "  This script must be called from the base directory of the package, and"
    echo "  requires utilites from these packages: dpkg-dev, mercurial-buildpackage"
    echo ""
    exit
  fi
done

package="rubyluabridge"

if [ ! -x /usr/bin/dpkg-parsechangelog ]; then
  echo "Missing the dpkg-parsechangelog utility from the dpkg-dev package"
  exit 1
fi

if [ ! -f debian/changelog ]; then
  echo "This script must be called from the base directory of the package"
  exit 1
fi

if [ ! -d .hg ]; then
  echo "This script only works from within a mercurial repository"
  exit 1
fi

if [ ! -x /usr/bin/mercurial-buildpackage ]; then
  echo "Missing mercurial-buildpackage"
  exit 1
fi

changelog_package=$(dpkg-parsechangelog | sed -n 's/^Source: //p')
if [ "${package}" != "${changelog_package}" ]; then
  echo "This script is configured to create snapshots for ${package} but you are trying to create a snapshot for ${changelog_package}"
  exit 1
fi

bare_upstream_version=$(dpkg-parsechangelog | sed -n 's/^Version: \+\([^+]\+\)\(+hg[0-9]\{8\}\)\?-.*/\1/p')
echo "Found bare upstream version: ${bare_upstream_version}"
snapshot_version="${bare_upstream_version}+hg$(date +%Y%m%d)"
echo "Upstream snapshot version: ${snapshot_version}"

current_branch=$(hg branch)
if [ -z "$(expr match "${current_branch}" '.*\(snapshot\)')" ]; then
  echo "This script can only be called from a branch ending in \"snapshot\""
  exit 1
fi

echo "Merging in default branch"
if hg merge default --tool internal:merge --pager never; then
  echo "Merge successful"
  hg commit -m "Merge in default branch"
elif [ $? -eq 1 ]; then
  echo "Merge failed"
  exit 1
elif [ $? -eq 255 ]; then
  echo "Nothing to merge"
fi

if [ -f ../${package}_${snapshot_version}.orig.tar.gz ]; then
  echo "Upstream tarball snapshot has already been created"
else
  echo "Creating upstream tarball snapshot"
  hg update default
  hg archive ../${package}_${snapshot_version}.orig.tar.gz
  hg update ${current_branch}
  echo "Making Debian changelog entry"
  dch -v "${snapshot_version}-1" -D UNRELEASED "Built from mercurial snapshot."
  hg commit -m "Debian changelog entry for building package from mercurial snapshot."
fi

echo "Calling mercurial-buildpackage ..."
mercurial-buildpackage "$@"

