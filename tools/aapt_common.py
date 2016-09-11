"""Common functions used in preparing aapt processing."""

import codecs
import collections
import hashlib
import itertools
import math
import os
import os.path
import shutil
import subprocess
import tarfile
import tempfile
import xml.dom.minidom
import xml.parsers.expat

VALUES_DIR = 'values'

AAPT_SIMPLE_FLAGS = set([
    '--debug-mode',
    '--utf16',
    '--auto-add-overlay',
    '-d', '-f', '-m', '-u', '-v', '-x', '-z'
])

DENSITY = {
    'ldpi': 120,
    'mdpi': 160,
    'tvdpi': 213,
    'hdpi': 240,
    '280dpi': 280,
    'xhdpi': 320,
    '340dpi': 340,
    '400dpi': 400,
    '420dpi': 420,
    'xxhdpi': 480,
    '560dpi': 560,
    'xxxhdpi': 640,
}

SCREEN_SIZES = [
    'small',
    'normal',
    'large',
    'xlarge'
]

PLAY_STORE_SUPPORTED_DENSITIES = {
    'ldpi': 'ldpi',
    'mdpi': 'mdpi',
    'tvdpi': '213',
    'hdpi': 'hdpi',
    '280dpi': '280',
    'xhdpi': 'xhdpi',
    '400dpi': '400',
    '420dpi': '420',
    'xxhdpi': '480',
    '560dpi': '560',
    'xxxhdpi': '640',
}

RES_FOLDER_NAMES = [
    'animator',
    'anim',
    'color',
    'drawable',
    'interpolator',
    'layout',
    'menu',
    'mipmap',
    'raw',
    'transition',
    'values',
    'xml']

ADDITIONAL_AAPT_FLAGS = [
    # Do not generate versioned copies of vector XML resources.
    '--no-version-vectors'
]

# This is compressed appcompat resources. It should never passed to the aapt
# invocation.
MAGIC_FILE = 'raw/blaze_internal_packed_resources.tar'


def _GroupBy(inputitr, sortkey):
  return itertools.groupby(sorted(inputitr, key=sortkey), sortkey)


def CleanUpDirectory(directory):
  # Swallow errors because the directory may not exist. This is a cleanup
  # measure to ensure the directories are empty.
  shutil.rmtree(directory, onerror=lambda function, path, excinfo: None)


def CreateOutputDirectory(directory):
  CleanUpDirectory(directory)
  os.makedirs(directory)


def Deprefix(string, prefix):
  if not string.startswith(prefix):
    raise AssertionError("%s doesn't start with %s" % (string, prefix))
  return string[len(prefix) + 1:]


class AaptLayout(object):
  """Represents a collection of directories necessary for execution of aapt.

  Provides a temporary  aapt execution environment by creating directories and
  copying the necessary files into a working directory when used as the
  expression for a 'with' statement.

  When entering the 'with' block, all directories are setup and exiting removes
  them.
  """

  def __init__(self, aapt_directories, r_txt_dir):
    """Creates a new AaptLayout.

    Args:
      aapt_directories: A list of AaptDirectories with unique destination
        directories.
      r_txt_dir: A directory string, if not None, that should have the R.txt
         after the aapt invocation. If the R.txt does not exist, it will be
         created as an empty file.
    """
    self.__aapt_directories = list(aapt_directories)
    self.__r_txt_dir = r_txt_dir

  def __eq__(self, other):
    if isinstance(other, AaptLayout):
      return vars(self) == vars(other)
    return False

  def __enter__(self):
    for directory in self.__aapt_directories:
      directory.__enter__()
    if self.__r_txt_dir and not os.path.exists(self.__r_txt_dir):
      os.makedirs(self.__r_txt_dir)

  def __exit__(self, *_):
    for directory in self.__aapt_directories:
      directory.__exit__()
    if self.__r_txt_dir and not os.path.isfile(os.path.join(self.__r_txt_dir,
                                                            'R.txt')):
      # aapt doesn't generate an R.txt if there are no resources, but Blaze
      # expects one. So, create it.
      with open(os.path.join(self.__r_txt_dir, 'R.txt'), 'a'):
        pass

  def __repr__(self):
    return 'AaptLayout(%s)' % self.__aapt_directories


class AaptDirectory(object):
  """Represents the directory structure necessary to run the aapt tool.

  When used in the context of a 'with' statement, entering the block will cause
  all paths will be copied from the source to the destination directory. Exiting
  causes the directories to be removed.
  """

  def __init__(self, paths, dest_dir, densities=None):
    """Creates a new AaptDirectory.

    Args:
      paths: A list of (source path, resource relative path,
        destination resource directory) tuples to be copied to the destination
        directory. The paths may be either files or directories. If the path is
        a directory, all contents are recursively copied as well.
      dest_dir: The destination directory.
      densities: A list of densities to filter with.
    """
    self.__paths = sorted(paths)
    self.dest_dir = dest_dir
    self.__densities = densities or []

  def __eq__(self, other):
    if isinstance(other, AaptDirectory):
      return vars(self) == vars(other)
    return False

  def __ne__(self, other):
    return not self.__eq__(other)

  def __cmp__(self, other):
    # pylint: disable=protected-access
    # (we are only accessing our own class' private fields here)
    return cmp(self.__paths + [self.dest_dir], other.__paths + [other.dest_dir])

  def __repr__(self):
    return 'AaptDirectory(%s, %s, %s)' % (self.__paths, self.dest_dir,
                                          self.__densities)

  def __enter__(self):
    """When entering, copy all paths to the destination directory."""
    CreateOutputDirectory(self.dest_dir)

    # dictionary of dest->[(src path, resource dir)...]
    copy_queue = collections.defaultdict(list)

    for src_path, relative_path, resource_dir in self.__paths:
      if os.path.isdir(src_path):
        for root, _, paths in os.walk(src_path, followlinks=True):
          # calculates the relative path
          relative_dir = Deprefix(root, src_path)
          for path in paths:
            self._AddFileToQueue(
                copy_queue,
                os.path.join(relative_dir, path),
                os.path.join(root, path),
                resource_dir)
      else:
        self._AddFileToQueue(copy_queue,
                             relative_path,
                             src_path,
                             resource_dir)

    relative_paths = _MatchResources(
        copy_queue.keys(),
        self.__densities) if self.__densities else copy_queue.keys()
    for relative_path in relative_paths:
      srcs = copy_queue[relative_path]
      # check the file contents to avoid duplicating files in the resource
      # values directories.
      copied = set()
      check_duplicates = len(srcs) > 1
      for src_path, resource_dir in srcs:
        # always prepare the path
        path = self.__PreparePath(os.path.join(resource_dir, relative_path))
        # omit duplicated files in the values directory
        if check_duplicates and relative_path.startswith(VALUES_DIR):
          with open(src_path) as src_file:
            file_hash = hashlib.md5(src_file.read()).digest()
          if file_hash in copied:
            # if the file is the same as a copied file, don't copy it,
            # otherwise aapt will fail with duplicate key exceptions when aapt
            # processes the values directories for keys.
            continue
          copied.add(file_hash)
        shutil.copy2(src=src_path, dst=path)

  def __PreparePath(self, path):
    full_path = os.path.join(self.dest_dir, path)
    path_dir = os.path.dirname(full_path)
    if not os.path.isdir(path_dir):
      os.makedirs(path_dir)
    return full_path

  def _AddFileToQueue(self, queue, relative_path, src_path, dest_dir):
    """Adds queue[relative_path] ->(src_path, dest_dir, overwrite).

    Part of adding the file is to detect if a path matches the MAGIC_FILE,
    a work around for the appcompat library resources which currently reside in
    a .tar file. If found, they will be expanded to a temporary directory and
    added to the copy queue.

    Args:
      queue: A dict(relative_path->(source_path, destination_dir)) that acts as
        a queue of files to copy.
      relative_path: The path relative to the root directory (including the
        prefix.
      src_path: The complete path of the file.
      dest_dir: The destination to copy the file to.
    """
    if src_path.endswith(MAGIC_FILE):
      tar_res_dir = os.path.dirname(os.path.dirname(src_path))
      with tarfile.open(src_path) as tar:
        res_tmp = tempfile.mkdtemp()
        for member in tar.getmembers():
          if member.isfile():
            self._MemberSanityCheck(member, src_path, tar_res_dir)
            relative_path = member.name[len('./'):]
            # If a file exists in the directory we found the magic tar file,
            # unpack the file to a different name to avoid collisions.
            if os.path.exists(os.path.join(tar_res_dir, relative_path)):
              relative_path = '%s-appcompat%s' % os.path.splitext(
                  relative_path)
              new_src_path = os.path.join(res_tmp, relative_path)
              new_src_dir = os.path.dirname(new_src_path)
              if not os.path.isdir(new_src_dir):
                os.makedirs(new_src_dir)
              with open(new_src_path, 'wb') as out:
                shutil.copyfileobj(tar.extractfile(member), out)
            else:
              tar.extract(member, res_tmp)

            queue[relative_path].append((os.path.join(res_tmp, relative_path),
                                         dest_dir))
    else:
      queue[relative_path].append((src_path, dest_dir))

  def _MemberSanityCheck(self, member, arg, res_dir):
    """Ensures that a filename in an archive will be well behaved.

    Expansion shouldn't overwrite pre-existing files (Except in values dir)
    Expansion should stay beneath res_dir
    Expansion should be into one of the well-known resfolders.
    Arguments:
      member: tarinfo to consider
      arg: the commandline argument part
      res_dir: the resources dir we want to expand into
    Raises:
      AssertionError: if expansion will cause problems.
    """
    if os.path.exists(os.path.join(res_dir, member.name)):
      folder_name = os.path.basename(os.path.dirname(member.name))
      if not folder_name.startswith(VALUES_DIR):
        raise AssertionError('%s: %s collides with %s:' % (
            arg, member.name, os.path.join(res_dir, member.name)))
    norm_res_folder = os.path.normpath(res_dir)
    norm_name = os.path.normpath(os.path.join(res_dir, member.name))
    if not norm_name.startswith(norm_res_folder):
      raise AssertionError('%s: %s would write outside of dir %s' %
                           (arg, member.name, res_dir))
    res_folder_name = os.path.basename(os.path.dirname(norm_name))
    qualifier_idx = res_folder_name.find('-')
    if qualifier_idx != -1:
      res_folder_name = res_folder_name[:qualifier_idx]
    if res_folder_name not in RES_FOLDER_NAMES:
      raise AssertionError('%s: %s not in a known res folder (%s)' %
                           (arg, member.name, res_folder_name))

  def __exit__(self, *_):
    """Clean up the destination directory."""
    CleanUpDirectory(self.dest_dir)


def _MatchResources(resourcepaths, densities):
  """Takes a list of android resource paths and filters them by density."""
  def _SplitQualifiers(path):
    """Splits a resource path into type, qualifiers, density, and id."""
    split_path = collections.namedtuple(
        'SplitPath', ['path', 'restype', 'qualifiers', 'density', 'resid'])
    qualifiers = os.path.dirname(path)
    resid = path.replace(qualifiers + '/', '')
    qualifiers = qualifiers.replace(os.path.dirname(qualifiers) + '/', '')
    density = ''
    for checkdensity in itertools.chain(['nodpi'], DENSITY):
      if '-' + checkdensity in qualifiers:
        qualifiers = qualifiers.replace('-' + checkdensity, '')
        density = checkdensity
    restype = qualifiers.split('-')[0]
    qualifiers = '-'.join(qualifiers.split('-')[1:])
    return split_path(path, restype, qualifiers, density, resid)

  def _MatchScore(path, density):
    """Computes a resource and a density score, lower is a closer match."""
    if path.density == density:
      return -2
    affinity = math.log(float(DENSITY[density]) / DENSITY[path.density], 2)
    if affinity == -1:
      # It's very efficient to downsample an image that's exactly 2x the screen
      # density, so we prefer that over other non-perfect matches
      return affinity
    if affinity < 0:
      # We give a slight bump to images that have the same multiplier but are
      # higher quality.
      affinity = abs(affinity + 0.01)
    return affinity

  for density in densities:
    if density not in DENSITY:
      raise AssertionError('%s is not a known density qualifier.' % (density))
  inres = set([_SplitQualifiers(x) for x in resourcepaths])
  outres = set([])
  for respath in list(inres):
    if (respath.restype != 'drawable'
        or (not respath.density)
        or respath.density == 'nodpi'
        or respath.resid.endswith('.xml')):
      inres.remove(respath)
      outres.add(respath)
  inres = frozenset(inres)
  for _, reslist in _GroupBy(inres, lambda x: x.resid):
    for _, optionslist in _GroupBy(reslist, lambda x: x.qualifiers):
      optionslist = list(optionslist)
      if len(optionslist) == 1:
        outres.add(optionslist[0])
        continue
      for density in densities:
        outres.add(min(optionslist, key=lambda x: _MatchScore(x, density)))

  return frozenset([x.path for x in outres])


class ManifestProcessingException(Exception):
  pass


class AaptEnvironmentBuilder(object):
  """Handles the parsing of an aapt command line from blaze.

  An aapt commandline is expect to be in this form:
      [<resources_arguments>] [<assets_arguments>] <aapt_arguments>

  Notes:
       <resources_arguments> is optional and contains:
          start_resources <destination_dir>
            <artifact_exec_path> <resources_dir_relative_path>...
            end_resources
       <assets_arguments> is optional and contains:
          start_assets <destination_dir>
            <artifact_exec_path> <assets_dir_relative_path>...
            end_assets
       <aapt_argument> is mandatory and contains aapt invocation and aapt flags.

  Examples:
    Given the arguments:
      ['start_resources',
       'working/directory',
       'foo/res', 'foo/res',
       'bar/res_one', 'working/director/bar/res_one',
       'baz/res/values/strings.xml',
       'baz/res/values/strings.xml'
       'zub/res/values/strings.xml',
       'zub/res/values/strings.xml'
       'end_resources',
       'path/to/android_tool_launcher', 'path/to/aapt_binary',
       '-S', 'working/directory/foo/res',
       '-S', 'working/directory/bar/res_one',
       '-S', 'working/directory/baz/res',
       '-S', 'working/directory/baz/res',
       'working/directory/raw/files/directory'
      ]

    Will create the following aapt command line:
       path/to/android_tool_launcher path/to/aapt_binary\
         -S working/directory/foo/res\
         -S working/directory/bar/res_one\
         -S working/directory/baz/res\
         -S working/directory/zab/res\
         working/directory/raw/files/directory

    With a directory structure of:
       working/directory/foo/res # containing all the files beneath
       working/directory/bar/res_one
       working/directory/baz/res

    Attributes:
      arguments: A list of string representing the arguments for the aapt run.
      raw_files_directories: A list of raw file directories to pass to aapt.
      aapt_flags: A list of flags for aapt.
      aapt_directories: A dictionary of destination directory to AaptDirectory.
  """

  def __init__(self, arguments):
    """Creates a new AaptCommandLineParser.

    Args:
      arguments: A list of strings containing arguments for the aapt run.
        See class description.
    """
    self.arguments = list(arguments)
    self.densities = []
    self.raw_files_directories = []
    self.aapt_binary_args = []
    self.aapt_flags = []
    self.aapt_directories = {}  # using a map to validate all destination
    # directories are unique.
    self.r_txt_dir = None

  def __ParseAaptArguments(self):
    """Parse aapt invocation arguments for binary, flags, and directories."""
    # aapt invocation should be in the form
    # [paths to aapt and helpers] [...flags...][raw directories]
    while self.arguments and not self.arguments[0].startswith('-'):
      if self.arguments[0].startswith('start_'):
        raise AssertionError('Resources should be parsed before aapt arguments')
      self.aapt_binary_args.append(self.arguments.pop(0))

    # parse flags
    while self.arguments and self.arguments[0].startswith('-'):
      flag = self.arguments.pop(0)
      self.aapt_flags.append(flag)
      # add the value
      if flag not in AAPT_SIMPLE_FLAGS:
        value = self.arguments.pop(0)
        if flag == '--output-text-symbols':
          self.r_txt_dir = value
        self.aapt_flags.append(value)

    # parse raw file directories
    while self.arguments:
      self.raw_files_directories.append(self.arguments.pop(0))

  def ConsumeDensityArgs(self):
    """Consumes a list of density filters.

    Returns:
      The current builder.
    Raises:
      AssertionError: When an unknown density is specified.
    """
    if self.arguments[0] != 'start_densities':
      return self
    self.arguments.pop(0)  # pop start marker
    while self.arguments[0] != 'end_densities':
      density = self.arguments.pop(0)
      if density not in DENSITY:
        raise AssertionError('Unknown density: %s' % density)
      self.densities.append(density)
    self.arguments.pop(0)  # pop end marker
    return self

  def ConsumeResourceArgs(self, suffix, flag):
    """Consumes a set of resources or assets into an AaptDirectory.

    Each resource is given a destination path relative to the
    resource directory defined by the flag argument.

    Args:
      suffix: The suffix of the start and end tokens.
      flag: The aapt flag for the corresponding suffix type.
    Returns:
      The current builder.
    Raises:
      AssertionError: When two resources use the same destination directory.
    """
    start = 'start_' + suffix
    end = 'end_' + suffix

    # find aapt args to get the directory list
    def _FindFlagValues():
      arguments_iter = iter(self.arguments)
      for arg in arguments_iter:
        if arg == flag:
          yield arguments_iter.next()

    def _SplitPath(path):
      for resource_directory in resource_directories:
        if path.startswith(resource_directory):
          return (path[len(resource_directory) + 1:], resource_directory)
      raise AssertionError(
          '%s is not found under %s' % (path, resource_directories))

    if self.arguments and start == self.arguments[0]:
      self.arguments.pop(0)  # remove the start token
      dest_dir = self.arguments.pop(0)

      resource_directories = [
          Deprefix(v, dest_dir) for v in _FindFlagValues()
      ]
      if dest_dir in self.aapt_directories:
        raise AssertionError('Duplicated destination directory %s' % dest_dir)

      path_tuples = []
      while self.arguments[0] != end:
        source_path = self.arguments.pop(0)
        relative_path, resource_dir = _SplitPath(self.arguments.pop(0))
        path_tuples.append((source_path, relative_path, resource_dir))
      self.arguments.pop(0)  # remove end token

      self.aapt_directories[dest_dir] = AaptDirectory(
          path_tuples,
          dest_dir,
          densities=self.densities if suffix == 'resources' else [])
    return self

  def AddCompatibleScreensToManifest(self):
    """Adds a &lt;compatible-screens&gt; section to the manifest.

    The &lt;compatible-screens&gt; section is created if it does not exist and
    populated with &lt;screen&gt; elements. The generated elements correspond to
    the density arguments from the command line. If the manifest already
    contains a superset of the &lt;compatible-screens&gt; section to be created,
    it is left unchanged. The manifest flag (-M) is replaced with the path of
    the modified manifest.

    Returns:
      The current builder.
    Raises:
      AssertionError: When the manifest cannot be properly modified.
    """
    if not self.densities:
      return self

    if '-M' not in self.arguments:
      return self

    manifest_value_index = self.arguments.index('-M') + 1
    manifest_path = self.arguments[manifest_value_index]
    manifest_dir = os.path.dirname(manifest_path)

    try:
      doc = xml.dom.minidom.parse(self.arguments[manifest_value_index])

      manifest_elements = doc.getElementsByTagName('manifest')
      if manifest_elements.length != 1:
        raise ManifestProcessingException(
            'Manifest {0} does not contain exactly one <manifest> tag. '
            'It contains {1}.'.format(manifest_path, manifest_elements.length))

      manifest_element = manifest_elements.item(0)

      existing_densities = set()
      for screen in doc.getElementsByTagName('screen'):
        existing_densities.add(screen.getAttribute('android:screenDensity'))
      if existing_densities.issuperset({PLAY_STORE_SUPPORTED_DENSITIES[x]
                                        for x in self.densities
                                        if x in PLAY_STORE_SUPPORTED_DENSITIES
                                       }):
        return self

      compatible_screens_elements = doc.getElementsByTagName(
          'compatible-screens')
      for compatible_screens_element in compatible_screens_elements:
        compatible_screens_element.parentNode.removeChild(
            compatible_screens_element)

      # If the list of densities contains a density not supported by the Play
      # Store, omit the <compatible-screens> declaration from the manifest to
      # indicate that this APK supports all densities. This is a temporary fix
      # to support new density buckets until the Play Store introduces a new
      # density targeting mechanism.
      if set(self.densities).issubset(PLAY_STORE_SUPPORTED_DENSITIES):
        compatible_screens = doc.createElement('compatible-screens')
        manifest_element.appendChild(compatible_screens)

        for density in self.densities:
          for screen_size in SCREEN_SIZES:
            screen = doc.createElement('screen')
            screen.setAttribute('android:screenSize', screen_size)
            screen.setAttribute('android:screenDensity',
                                PLAY_STORE_SUPPORTED_DENSITIES[density])
            compatible_screens.appendChild(screen)

      modified_file_path = os.path.join(manifest_dir, 'manifest-filtered',
                                        'AndroidManifest.xml')
      if not os.path.exists(os.path.dirname(modified_file_path)):
        os.makedirs(os.path.dirname(modified_file_path))
      with codecs.open(modified_file_path, 'w', 'utf-8') as modified_file:
        doc.documentElement.writexml(modified_file)

      self.arguments[manifest_value_index] = modified_file_path
    except (xml.parsers.expat.ExpatError, IOError), e:
      raise ManifestProcessingException(str(e))

    return self

  def Build(self):
    self.__ParseAaptArguments()
    return AaptEnvironment(
        self.aapt_binary_args + ADDITIONAL_AAPT_FLAGS + self.aapt_flags +
        self.raw_files_directories, AaptLayout(
            sorted(self.aapt_directories.values()), self.r_txt_dir))


class AaptEnvironment(object):
  """Handles the setup and execution of the aapt tool."""

  def __init__(self, arguments, layout):
    """Creates a new AaptEnvironment.

    Args:
      arguments: A list of strings, starting with the path to the executable
         aapt, followed by flags.
      layout: An AaptLayout with the resources and assets populated.
    """
    self.arguments = arguments
    self.layout = layout

  def Execute(self):
    """Executes the aapt arguments with the correct aapt layout."""
    with self.layout:
      subprocess.check_call(self.arguments)


def RunAapt(arguments):
  """Runs the aapt tool on the command line.

  Args:
    arguments: A list of strings taken from the command line. The list is
      expected to be as follows:
      [<density_arguments>] [<resources_arguments>] [<assets_arguments>]
      <aapt_arguments>

       <density_arguments> is optional and contains:
          start_densities <density1 (eg, xxhdpi)> <density2>...
          end_densities
       <resources_arguments> is optional and contains:
          start_resources <destination_dir>
            <artifact_exec_path> <resources_dir_relative_path>...
            end_resources
       <assets_arguments> is optional and contains:
          start_assets <destination_dir>
            <artifact_exec_path> <assets_dir_relative_path>...
            end_assets
       <aapt_argument> is mandatory and contains aapt invocation and flags.
  """
  builder = AaptEnvironmentBuilder(arguments)
  builder.ConsumeDensityArgs()
  builder.ConsumeResourceArgs('resources', '-S')
  builder.ConsumeResourceArgs('assets', '-A')
  builder.AddCompatibleScreensToManifest()
  builder.Build().Execute()


def MaybeUnpackParamFile(args):
  """Unpacks arguments from a param file or just returns them if not.

  If the arguments array contains only one element that starts with a '@' it is
  assumed to be parameter file used to circumvent the case where the command
  line is over 32768 characters. This function will read the file from disk
  and return the contents in the form of an array. The param file is presumed to
  be quoted appropriately for shell usage.

  Args:
    args: A list of string arguments that may contain a param file
  Returns:
    A list of string arguments that can be consumed by aapt_common.RunAapt().
  """
  if len(args) == 1 and args[0].startswith('@'):
    with open(args[0][1:]) as param_file:
      return param_file.read().strip().split('\n')
  return args
