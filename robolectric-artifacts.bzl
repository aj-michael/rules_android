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

lib_artifacts_by_version = {
    "3.1.2": [
        "com.almworks.sqlite4java:sqlite4java:0.282",
        "com.google.android.apps.common.testing.accessibility.framework:accessibility-test-framework:2.1",
        "com.google.guava:guava:19.0",
        "com.ibm.icu:icu4j:53.1",
        "com.thoughtworks.xstream:xstream:1.4.8",
        "com.ximpleware:vtd-xml:2.11",
        "org.apache.ant:ant:1.8.0",
        "org.apache.httpcomponents:httpclient:4.0.3",
        "org.apache.maven:maven-ant-tasks:2.1.3",
        "org.bouncycastle:bcprov-jdk16:1.46",
        "org.ow2.asm:asm-analysis:5.0.1",
        "org.ow2.asm:asm-commons:5.0.1",
        "org.ow2.asm:asm-tree:5.0.1",
        "org.ow2.asm:asm-util:5.0.1",
        "org.ow2.asm:asm:5.0.1",
        "org.robolectric:robolectric-annotations:3.1.2",
        "org.robolectric:robolectric-resources:3.1.2",
        "org.robolectric:robolectric-utils:3.1.2",
        "org.robolectric:robolectric:3.1.2",
        "org.robolectric:shadows-core-v23:3.1.2",
    ],
    "3.1.1": [
        "org.robolectric:robolectric:3.1.1",
        "org.robolectric:robolectric-annotations:3.1.1",
        "org.robolectric:robolectric-resources:3.1.1",
        "org.robolectric:robolectric-utils:3.1.1",
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

shadows_artifacts_by_version = {
    "3.1.2": [
        "org.robolectric:shadows-httpclient:3.1.2",
        "org.robolectric:shadows-multidex:3.1.2",
        "org.robolectric:shadows-play-services:3.1.2",
        #"org.robolectric:shadows-core-v23:3.1.2",
        "org.robolectric:shadows-core-v22:3.1.2",
        "org.robolectric:shadows-core-v21:3.1.2",
        "org.robolectric:shadows-core-v19:3.1.2",
        "org.robolectric:shadows-core-v18:3.1.2",
        "org.robolectric:shadows-core-v17:3.1.2",
        "org.robolectric:shadows-core-v16:3.1.2",
    ],
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
android_os_artifacts_by_version = {
    "6.0.0": ["org.robolectric:android-all:6.0.0_r1-robolectric-0"],
    "5.1.1": ["org.robolectric:android-all:5.1.1_r9-robolectric-1"],
    "5.0.0": ["org.robolectric:android-all:5.0.0_r2-robolectric-1"],
    "4.4": ["org.robolectric:android-all:4.4_r1-robolectric-1"],
    "4.3": ["org.robolectric:android-all:4.3_r2-robolectric-0"],
    "4.2.2": ["org.robolectric:android-all:4.2.2_r1.2-robolectric-0"],
    "4.1.2": ["org.robolectric:android-all:4.1.2_r1-robolectric-0"],
}
