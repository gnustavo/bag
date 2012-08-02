#!/bin/bash
# CVS to Git converter
# See http://cvs2svn.tigris.org/cvs2git.html

# Copyright (C) 2012 by CPqD

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# http://www.dwheeler.com/essays/fixing-unix-linux-filenames.html
set -eu
IFS=`printf '\n\t'`

usage="usage: $0 CVSDIR GITDIR"

if [ $# -ne 2 ]; then
    echo >&2 $usage
    exit 1
fi

FROM="$1"
TO="$2"

if ! test -d "$FROM"; then
    echo >&2 "No such directory: $FROM"
    exit 1
fi

FROM=`(cd $FROM; pwd)`

if ! test -d "$FROM"; then
    echo >&2 "No such directory: $FROM"
    exit 1
fi

if test -d "$TO"; then
    echo >&2 "This directory should not exist: $TO"
    exit 1
fi

set -x

mkdir -p "$TO"

cd "$TO"

TMPDIR=`mktemp -d /tmp/tmp.XXXXXXXXXX` || exit 1
trap "rm -rf $TMPDIR" EXIT

cat >$TMPDIR/cvs2git.options <<'EOF'
# coding=utf-8
import re
from cvs2svn_lib import config
from cvs2svn_lib import changeset_database
from cvs2svn_lib.common import CVSTextDecoder
from cvs2svn_lib.log import Log
from cvs2svn_lib.project import Project
from cvs2svn_lib.git_revision_recorder import GitRevisionRecorder
from cvs2svn_lib.git_output_option import GitRevisionMarkWriter
from cvs2svn_lib.git_output_option import GitOutputOption
from cvs2svn_lib.revision_manager import NullRevisionRecorder
from cvs2svn_lib.revision_manager import NullRevisionExcluder
from cvs2svn_lib.fulltext_revision_recorder import SimpleFulltextRevisionRecorderAdapter
from cvs2svn_lib.rcs_revision_manager import RCSRevisionReader
from cvs2svn_lib.cvs_revision_manager import CVSRevisionReader
from cvs2svn_lib.checkout_internal import InternalRevisionRecorder
from cvs2svn_lib.checkout_internal import InternalRevisionExcluder
from cvs2svn_lib.checkout_internal import InternalRevisionReader
from cvs2svn_lib.symbol_strategy import AllBranchRule
from cvs2svn_lib.symbol_strategy import AllTagRule
from cvs2svn_lib.symbol_strategy import BranchIfCommitsRule
from cvs2svn_lib.symbol_strategy import ExcludeRegexpStrategyRule
from cvs2svn_lib.symbol_strategy import ForceBranchRegexpStrategyRule
from cvs2svn_lib.symbol_strategy import ForceTagRegexpStrategyRule
from cvs2svn_lib.symbol_strategy import ExcludeTrivialImportBranchRule
from cvs2svn_lib.symbol_strategy import ExcludeVendorBranchRule
from cvs2svn_lib.symbol_strategy import HeuristicStrategyRule
from cvs2svn_lib.symbol_strategy import UnambiguousUsageRule
from cvs2svn_lib.symbol_strategy import HeuristicPreferredParentRule
from cvs2svn_lib.symbol_strategy import SymbolHintsFileRule
from cvs2svn_lib.symbol_transform import ReplaceSubstringsSymbolTransform
from cvs2svn_lib.symbol_transform import RegexpSymbolTransform
from cvs2svn_lib.symbol_transform import IgnoreSymbolTransform
from cvs2svn_lib.symbol_transform import NormalizePathsSymbolTransform
from cvs2svn_lib.property_setters import AutoPropsPropertySetter
from cvs2svn_lib.property_setters import CVSBinaryFileDefaultMimeTypeSetter
from cvs2svn_lib.property_setters import CVSBinaryFileEOLStyleSetter
from cvs2svn_lib.property_setters import CVSRevisionNumberSetter
from cvs2svn_lib.property_setters import DefaultEOLStyleSetter
from cvs2svn_lib.property_setters import EOLStyleFromMimeTypeSetter
from cvs2svn_lib.property_setters import ExecutablePropertySetter
from cvs2svn_lib.property_setters import KeywordsPropertySetter
from cvs2svn_lib.property_setters import MimeMapper
from cvs2svn_lib.property_setters import SVNBinaryFileKeywordsPropertySetter

Log().log_level = Log.NORMAL

ctx.revision_recorder = SimpleFulltextRevisionRecorderAdapter(
    CVSRevisionReader(cvs_executable=r'cvs'),
    GitRevisionRecorder('tmp/git-blob.dat'),
    )

ctx.revision_excluder = NullRevisionExcluder()

ctx.revision_reader = None

ctx.sort_executable = r'sort'

ctx.trunk_only = False

ctx.cvs_author_decoder = CVSTextDecoder(
    [
        'latin1',
        'utf8',
        'ascii',
        ],
    fallback_encoding='ascii'
    )

ctx.cvs_log_decoder = CVSTextDecoder(
    [
        'latin1',
        'utf8',
        'ascii',
        ],
    fallback_encoding='ascii'
    )

ctx.cvs_filename_decoder = CVSTextDecoder(
    [
        'latin1',
        'utf8',
        'ascii',
        ],
    )

ctx.initial_project_commit_message = (
    'Standard project directories initialized by cvs2git.'
    )

ctx.post_commit_message = (
    'This commit was generated by cvs2git to track changes on a CVS '
    'vendor branch.'
    )

ctx.symbol_commit_message = (
    "This commit was manufactured by cvs2git to create %(symbol_type)s "
    "'%(symbol_name)s'."
    )

ctx.decode_apple_single = False

ctx.symbol_info_filename = None

global_symbol_strategy_rules = [
    ExcludeTrivialImportBranchRule(),
    UnambiguousUsageRule(),
    BranchIfCommitsRule(),
    HeuristicStrategyRule(),
    HeuristicPreferredParentRule(),
    ]

ctx.username = 'cvs2git'

ctx.svn_property_setters.extend([
        CVSBinaryFileEOLStyleSetter(),
        CVSBinaryFileDefaultMimeTypeSetter(),
        DefaultEOLStyleSetter(None),
        SVNBinaryFileKeywordsPropertySetter(),
        KeywordsPropertySetter(config.SVN_KEYWORDS_VALUE),
        ExecutablePropertySetter(),
        ])

ctx.tmpdir = r'tmp'

ctx.cross_project_commits = False

ctx.cross_branch_commits = False

ctx.keep_cvsignore = False

ctx.retain_conflicting_attic_files = False

author_transforms={
    'jrandom' : ('J. Random', 'jrandom@example.com'),
    'mhagger' : ('Michael Haggerty', 'mhagger@alum.mit.edu'),
    'brane' : (u'Branko Čibej', 'brane@xbc.nu'),
    'ringstrom' : ('Tobias Ringström', 'tobias@ringstrom.mine.nu'),
    'dionisos' : (u'Erik Hülsmann', 'e.huelsmann@gmx.net'),
    'cvs2git' : ('cvs2git', 'admin@example.com'),
    }

ctx.output_option = GitOutputOption(
    'tmp/git-dump.dat',
    GitRevisionMarkWriter(),
    max_merges=None,
    author_transforms=author_transforms,
    )

run_options.profiling = False

run_options.set_project(
    r'CVSBASE',
    symbol_transforms=[
        ReplaceSubstringsSymbolTransform('\\','/'),
        NormalizePathsSymbolTransform(),
        ],
    symbol_strategy_rules=global_symbol_strategy_rules,
    )

EOF

sed -e "s:CVSBASE:$FROM:" $TMPDIR/cvs2git.options >cvs2git.options

if time cvs2git --options=cvs2git.options >&log.convert; then
    :
else
    echo >&2 "ERROR: See logs in $TO/log.convert"
    exit 1
fi

mkdir git
cd git
git init --bare



if cat ../tmp/git-blob.dat ../tmp/git-dump.dat | time git fast-import >&../log.import; then
    :
else
    echo >&2 "ERROR: See logs in $TO/log.import"
    exit 1
fi

set -x

cat <<EOF
The CVS repository $FROM was converted to the Git repository in $TO/git.

Convertion logs are available in $TO/log.convert

Import logs are available in $TO/log.import
EOF
