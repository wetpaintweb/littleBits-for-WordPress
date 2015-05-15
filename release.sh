#!/bin/bash

set -e

# Wordpress.org username
wordpressuser="wetpaintweb"

# Wordpress.org plugin name
package="littlebits"

version=$1

if [[ ! $version ]]; then
	echo "Needs a version number as argument"
	exit 1
fi

echo "Releasing version ${version}"

echo "Setting version number in readme.txt and php files"
perl -pi -e "s/Stable tag: .*/Stable tag: ${version}/g" README.txt
perl -pi -e "s/Version:           .*/Version:           ${version}/g" ${package}.php
perl -pi -e "s/this->version = '.*';/this->version = '${version}';/g" includes/class-${package}.php

if ([[ $(git status | grep readme.txt) ]] || [[ $(git status | grep ${package}.php) ]]); then
	echo "Committing changes"
	git add README.txt
	git add ${package}.php
	git add includes/class-${package}.php
	git commit -m"Update readme with new stable tag $version"
fi

echo "Tagging locally"
git tag $version

echo "Pushing tag to git"
git push --tags origin master

echo "Checking out current version on Wordpress SVN"
svn co https://plugins.svn.wordpress.org/${package}/trunk /tmp/release-${package}

echo "Copying in updated files"
rsync -rv --delete --exclude=".git" --exclude=".svn" --exclude="release.sh" --exclude="README.md" . /tmp/release-${package}/.

cd /tmp/release-${package}/
# Add and delete new/old files.
svn status | grep "^!" | awk '{print $2"@"}' | tr \\n \\0 | xargs -0 svn delete || true
svn status | grep "^?" | awk '{print $2"@"}' | tr \\n \\0 | xargs -0 svn add || true

echo "Commiting version ${version} to Wordpress SVN"
svn commit --username ${wordpressuser} -m"Releasing version ${version}" /tmp/release-${package}

echo "Creating version ${version} SVN tag"
svn copy --username ${wordpressuser} https://plugins.svn.wordpress.org/${package}/trunk https://plugins.svn.wordpress.org/${package}/tags/${version} -m"Creating new ${version} tag"

echo "Cleaning up"
rm -rf /tmp/release-${package}

echo "Done"
