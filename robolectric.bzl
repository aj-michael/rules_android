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
"""TODO(ajmichael): Add module docstring.

TODO(ajmichael): Describe this module.
"""

load(":robolectric-util.bzl", "safe_name", "map")
load(":robolectric-artifacts.bzl",
     "lib_artifacts_by_version",
     "shadows_artifacts_by_version",
     "android_os_artifacts_by_version")

# Convert a Maven Artifact name "groupId:artifactId:versionId" into the
# name of the maven_jar remote repository.
def _convert_artifact_to_dep(artifact):
  return Label("@%s//jar" % (safe_name(artifact)))

def _robolectric_deps_properties_impl(ctx):
  """Implementation for the 'robolectrics_deps_properties' rule."""
  android_os_artifacts = []
  for android_os_version in ctx.attr.android_os_versions:
    android_os_artifacts += android_os_artifacts_by_version.get(android_os_version)
  shadows_artifacts = shadows_artifacts_by_version.get(ctx.attr.robolectric_version)
  # The output file consists of lines of the form:
  #   <maven coordinate>:<jar file>
  lines = []
  for artifact in android_os_artifacts:
    artifact_string = artifact.replace(":", "\\:")
    root_dir = str(ctx.configuration.bin_dir)[0:str(ctx.configuration.bin_dir).rfind(ctx.configuration.bin_dir.path)]
    file_string = ctx.expand_location(
        "$(location %s)" % _convert_artifact_to_dep(artifact),
        ctx.attr.android_os_deps)
    lines.append("%s=%s/%s" % (artifact_string, root_dir, file_string))

  for artifact in shadows_artifacts:
    artifact_string = artifact.replace(":", "\\:")
    root_dir = str(ctx.configuration.bin_dir)[0:str(ctx.configuration.bin_dir).rfind(ctx.configuration.bin_dir.path)]
    file_string = ctx.expand_location(
        "$(location %s)" % _convert_artifact_to_dep(artifact),
        ctx.attr.shadows_deps)
    lines.append("%s=%s/%s" % (artifact_string, root_dir, file_string))

  file_content = "\n".join(lines) + "\n"
  ctx.file_action(
      output=ctx.outputs.output_file,
      content=file_content
  )

# A rule that generates the required input file "robolectric-deps.properties"
# to be placed in the CLASSPATH of the Robolectric-based test.
# Wiring this file to the eventual test might be accomplished via
# java_binary(classpath_resources)
robolectric_deps_properties = rule(
    attrs = {
        "android_os_versions": attr.string_list(mandatory = True),
        "robolectric_version": attr.string(mandatory = True),
        "android_os_deps": attr.label_list(mandatory = True),
        "shadows_deps": attr.label_list(mandatory = True),
    },
    outputs = {
        "output_file": "robolectric-deps.properties",
    },
    implementation = _robolectric_deps_properties_impl,
)

def _get_lib_deps(robolectric_version):
  if robolectric_version not in lib_artifacts_by_version:
    fail("Unrecognized Robolectric version: %s" % robolectric_version)
  return map(_convert_artifact_to_dep,
             lib_artifacts_by_version[robolectric_version])

def _get_shadows_deps(robolectric_version):
  if robolectric_version not in shadows_artifacts_by_version:
    fail("Unrecognized Robolectric version: %s" % robolectric_version)
  return map(_convert_artifact_to_dep,
             shadows_artifacts_by_version[robolectric_version])

def _get_android_os_deps(android_os_version):
  if android_os_version not in android_os_artifacts_by_version:
    fail("Unrecognized Android version: %s" % android_os_version)
  return map(_convert_artifact_to_dep,
             android_os_artifacts_by_version[android_os_version])

def robolectric_test(
    name,
    robolectric_version = "3.1.2",
    android_os_versions = ["6.0.0"],
    **kwargs):
  """A macro for expanding android_robolectric_test configurations and dependencies.

  Args:
    name: The name of the rule.
    robolectric_version: The version of robolectric to use.
    android_os_versions: A list of the Android OS versions to test against.
    **kwargs: Attributes for android_robolectric_test.
  """
  lib_deps = _get_lib_deps(robolectric_version)
  shadows_deps = _get_shadows_deps(robolectric_version)
  android_os_deps = []
  for android_os_version in android_os_versions:
    android_os_deps += _get_android_os_deps(android_os_version)

  robolectric_deps_properties(
      name = name + "_robolectric_deps_properties",
      android_os_versions = android_os_versions,
      robolectric_version = robolectric_version,
      android_os_deps = android_os_deps,
      shadows_deps = shadows_deps
  )

  # Now fill in additional arguments before passing through to
  # android_robolectric_test.
  if "deps" not in kwargs:
    kwargs["deps"] = []
  kwargs["deps"] += lib_deps + shadows_deps + android_os_deps

  if "classpath_resources" not in kwargs:
    kwargs["classpath_resources"] = []
  kwargs["classpath_resources"] += [":robolectric-deps.properties"]

  if "runtime_deps" not in kwargs:
    kwargs["runtime_deps"] = []
  # Perhaps use 'data' instead?
  kwargs["runtime_deps"] += android_os_deps + shadows_deps

  # Try to carry along AndroidManifest.xml or any other test xml files.
  if "data" not in kwargs:
    kwargs["data"] = []
  kwargs["data"] += native.glob(["**/*.xml"], exclude=[
      ".*",  # Exclude hidden files.
      ".*/**/*", "*/**/.*/*",  # Exclude hidden directories.
      "bazel*/**/*", "build*/**/*"  # Exclude any Bazel files or Gradle files.
  ])

  native.android_robolectric_test(name=name, **kwargs)
