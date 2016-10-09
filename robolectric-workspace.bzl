load(":robolectric-util.bzl", "safe_name")
load(":robolectric-artifacts.bzl",
     "lib_artifacts_by_version",
     "shadows_artifacts_by_version",
     "android_os_artifacts_by_version")

# A macro to be called from the a project's WORKSPACE file to load all remote repositories needed
# by robolectric.
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
