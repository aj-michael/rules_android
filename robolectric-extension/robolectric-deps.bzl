print("loading module robolectric-deps.bzl")

lib_deps_by_version = {
    "3.1.1": [
        "org.robolectric:robolectric:3.1.1",
        "org.robolectric:robolectric-annotations:3.1.1",
        "org.robolectric:robolectric-resources:3.1.1",
        "org.robolectric:robolectric-utils:3.1.1",
        "org.ow2.asm:asm:5.0.1",
        "org.ow2.asm:asm-util:5.0.1",
        "org.ow2.asm:asm-commons:5.0.1",
        "org.ow2.asm:asm-analysis:5.0.1",
    ],
    "3.1": [
        "org.robolectric:robolectric:3.1",
        "org.robolectric:robolectric-annotations:3.1",
        "org.robolectric:robolectric-resources:3.1",
        "org.robolectric:robolectric-utils:3.1",
    ],
    "3.0": [
        "org.robolectric:robolectric:3.0",
        "org.robolectric:robolectric-annotations:3.0",
        "org.robolectric:robolectric-resources:3.0",
        "org.robolectric:robolectric-utils:3.0",
    ],
}

shadows_deps_by_version = {
    "3.1.1": [
        "org.robolectric:shadows-httpclient:3.1.1",
        "org.robolectric:shadows-multidex:3.1.1",
        "org.robolectric:shadows-play-services:3.1.1",
        "org.robolectric:shadows-core-v23:3.1.1",
        "org.robolectric:shadows-core-v22:3.1.1",
        "org.robolectric:shadows-core-v21:3.1.1",
        "org.robolectric:shadows-core-v19:3.1.1",
        "org.robolectric:shadows-core-v18:3.1.1",
        "org.robolectric:shadows-core-v17:3.1.1",
        "org.robolectric:shadows-core-v16:3.1.1",
        "org.apache.ant:ant:1.8.0",
        "org.apache.maven:maven-ant-tasks:2.1.3",
    ],
    "3.1": [
        "org.robolectric:shadows-core:3.1",
        "org.robolectric:shadows-httpclient:3.1",
        "org.robolectric:shadows-multidex:3.1",
        "org.robolectric:shadows-play-services:3.1",
    ],
    "3.0": [
        "org.robolectric:shadows-core:3.0",
        "org.robolectric:shadows-httpclient:3.0",
        "org.robolectric:shadows-multidex:3.0",
        "org.robolectric:shadows-play-services:3.0",
    ],
}

# Versions of the android-all artifact in Maven Central.
#   See https://mvnrepository.com/artifact/org.robolectric/android-all
android_os_deps_by_version = {
    "6.0.0": ["org.robolectric:android-all:6.0.0_r1-robolectric-0"],
    "5.1.1": ["org.robolectric:android-all:5.1.1_r9-robolectric-1"],
    "5.0.0": ["org.robolectric:android-all:5.0.0_r2-robolectric-1"],
    "4.4": ["org.robolectric:android-all:4.4_r1-robolectric-1"],
    "4.3": ["org.robolectric:android-all:4.3_r2-robolectric-0"],
    "4.2.2": ["org.robolectric:android-all:4.2.2_r1.2-robolectric-0"],
    "4.1.2": ["org.robolectric:android-all:4.1.2_r1-robolectric-0"],
}
