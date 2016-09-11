#
# Robolectric tests should load this rule into their BUILD files.
# load(":robolectric.bzl", "robolectric_deps_properties")

load(":robolectric-util.bzl", "safe_name", "map")
load(":robolectric-deps.bzl", "lib_deps_by_version", "shadows_deps_by_version", "android_os_deps_by_version")

def _convert_artifact_to_dep(artifact):
  return Label("@%s//jar:file" % (safe_name(artifact)))

####
# Computed Dependency Methods
# The parameters match attribute names in 'robolectric_deps_properties'.
# The last parameter 'cfg' exists only for legacy reasons and should not be used.
# http://www.bazel.io/docs/skylark/cookbook.html#computed-dependencies
####

def _get_lib_deps(robolectric_version, cfg=None):
  print("Looking up robolectric_version='%s'" % (robolectric_version))
  return map(_convert_artifact_to_dep,
      lib_deps_by_version[robolectric_version])

def _get_shadows_deps(robolectric_version, cfg=None):
  print("Looking up robolectric_version='%s'" % (robolectric_version))
  return map(_convert_artifact_to_dep,
      shadows_deps_by_version[robolectric_version])

def _get_android_os_deps(android_os_version, cfg=None):
  print("Looking up android_os_version='%s'" % (android_os_version))
  return map(_convert_artifact_to_dep,
      android_os_deps_by_version[android_os_version])

# A useful rule for expanding all the configurations and dependencies needed for an android_robolectric_test().
def _robolectric_test_impl(ctx):
  print("_lib_deps = ", ctx.attr._lib_deps)
  print("_android_os_deps = ", ctx.attr._android_os_deps)
  print("_shadows_deps = ", ctx.attr._shadows_deps)

  properties_name = ctx.attr.name + "robolectric_deps_properties"
  robolectric_deps_properties(
    name = properties_name,
    android_os_version = ctx.android_os_version,
    robolectric_version = ctx.robolectric_version,
    android_os_deps = ctx.attr._android_os_deps,
    shadows_deps = ctx.attr._shadows_deps
  )

  test_attr = ctx.attr
  test_attr.deps = ctx.attr._lib_deps
  test_attr.classpath_resources = [Label(":" + properties_name)]
  test_attr.data = ctx.attr._android_os_deps + ctx.attr._shadows_deps
  android_robolectric_test(test_attr)

# A rule that generates the required input file "robolectric-deps.properties"
# to be placed in the CLASSPATH of the Robolectric-based test.
# Wiring this file to the eventual test might be accomplished via java_binary(classpath_resources)
robolectric_test = rule(
    attrs = {
        "robolectric_version": attr.string(
            default = "3.1.1",
            values = lib_deps_by_version.keys(),
        ),
        "android_os_version": attr.string(
            default = "6.0.0",
            values = android_os_deps_by_version.keys(),
        ),
        "_lib_deps": attr.label_list(default = _get_lib_deps),
        "_android_os_deps": attr.label_list(default = _get_android_os_deps),
        "_shadows_deps": attr.label_list(default = _get_shadows_deps),
    },
    implementation = _robolectric_test_impl,
)

# Implementation for the 'robolectrics_deps_properties' rule.
def _robolectric_deps_properties_impl(ctx):
  android_os_artifacts = android_os_deps_by_version.get(ctx.attr.android_os_version)
  shadows_artifacts = shadows_deps_by_version.get(ctx.attr.robolectric_version)
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
# Wiring this file to the eventual test might be accomplished via java_binary(classpath_resources)
robolectric_deps_properties = rule(
    attrs = {
        "android_os_version": attr.string(mandatory = True),
        "robolectric_version": attr.string(mandatory = True),
        "android_os_deps": attr.label_list(mandatory = True),
        "shadows_deps": attr.label_list(mandatory = True),
    },
    outputs = {
        "output_file": "robolectric-deps.properties",
    },
    implementation = _robolectric_deps_properties_impl,
)

# TODO:
# 1. Create a rule that wraps everything needed to call android_robolectric_test.
# 2. Define a robolectric_config
# 3. Provide robolectric_config as attr to robolectric_deps_properties, which uses providers.
# 4. Provide robolectric_config to a wrapper around android_robolectric_test(), which accesses
#    the providers in order to set attributes like deps, classpath_resources, etc.
