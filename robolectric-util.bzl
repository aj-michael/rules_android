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

# Convert invalid Bazel name characters to underscores.
def safe_name(name_):
  return name_.replace(':', '_').replace('-', '_').replace('.', '_')

# Creates a list where each item maps to func_ applied to the corresponding item
# in list_.
# See https://docs.python.org/2/library/functions.html#map
def map(func_, list_):
  newlist = []
  for item in list_:
    newlist.append(func_(item))
  return newlist
