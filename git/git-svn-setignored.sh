#!/bin/bash
# set excluded files for git-svn branch

hash git 2>/dev/null || { echo >&2 "You need to install git. Aborting."; exit 1; }

if ! git svn --help > /dev/null 2>&1; then
  echo >&2 "git-svn does not appear to be installed. Aborting."
  exit 1
fi

if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo >&2 "Current directory is not a git repository. Aborting."
  exit 1
fi

if ! [ -d .git/svn  ]; then
  echo >&2 "Current directory does not appear to be a git-svn working copy. Aborting."
  exit 1
fi

# set excluded files for project
echo "Setting excluded files and folders for git-svn project..."
git svn show-ignore > .git/info/exclude
