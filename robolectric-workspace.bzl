# Copyright 2016 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load(":robolectric-util.bzl", "safe_name")
load(":robolectric-artifacts.bzl",
     "lib_artifacts_by_version",
     "shadows_artifacts_by_version",
     "android_os_artifacts_by_version")

# A macro to be called from the a project's WORKSPACE file to load all remote
# repositories needed by robolectric.
def robolectric_jars(
    robolectric_versions=lib_artifacts_by_version.keys(),
    android_os_versions=android_os_artifacts_by_version.keys()):

  for robolectric_version in robolectric_versions:
    for artifact in lib_artifacts_by_version.get(robolectric_version):
      native.maven_jar(name = safe_name(artifact), artifact = artifact)
    for artifact in shadows_artifacts_by_version.get(robolectric_version):
      native.maven_jar(name = safe_name(artifact), artifact = artifact)

  for android_os_version in android_os_versions:
    for artifact in android_os_artifacts_by_version.get(android_os_version):
      native.maven_jar(name = safe_name(artifact), artifact = artifact)
