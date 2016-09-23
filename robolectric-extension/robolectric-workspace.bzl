# Perhaps move all this into a repository rule that others can load and run from their WORKSPACE file.
# http://www.bazel.io/docs/skylark/lib/globals.html#repository_rule

load(":robolectric-util.bzl", "safe_name")
load(":robolectric-deps.bzl", "lib_deps_by_version", "shadows_deps_by_version", "android_os_deps_by_version")

def robolectric_jars(
    robolectric_versions=lib_deps_by_version.keys(),
    android_os_versions=android_os_deps_by_version.keys()):
  # Initialize the version of junit needed.
  native.maven_jar(
      name = "junit_junit_4_12",
      artifact = "junit:junit:4.12",
  )
  
  for robolectric_version in robolectric_versions:
    for artifact in lib_deps_by_version.get(robolectric_version):
      # print("Making maven_jar(name=%s, artifact=%s)" % (safe_name(artifact), artifact))
      native.maven_jar(name = safe_name(artifact), artifact = artifact)
    for artifact in shadows_deps_by_version.get(robolectric_version):
      # print("Making maven_jar(name=%s, artifact=%s)" % (safe_name(artifact), artifact))
      native.maven_jar(name = safe_name(artifact), artifact = artifact)

  for android_os_version in android_os_versions:
    for artifact in android_os_deps_by_version.get(android_os_version):
      # print("Making maven_jar(name=%s, artifact=%s)" % (safe_name(artifact), artifact))
      native.maven_jar(name = safe_name(artifact), artifact = artifact)
