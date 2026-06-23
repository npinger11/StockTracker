#!/usr/bin/env python3
"""
generate_xcodeproj.py
Generates StockTracker.xcodeproj/project.pbxproj from the existing source tree.
Run once from the StockTracker/ root directory:
    python3 generate_xcodeproj.py
"""

import hashlib
import os
from pathlib import Path


# ---------------------------------------------------------------------------
# UUID helpers
# ---------------------------------------------------------------------------

def uid(seed: str) -> str:
    """Deterministic 24-char uppercase hex UUID derived from a seed string."""
    return hashlib.sha256(seed.encode()).hexdigest().upper()[:24]


# ---------------------------------------------------------------------------
# Project inventory
# ---------------------------------------------------------------------------

SOURCE_FILES = [
    "StockTracker/StockTrackerApp.swift",
    "StockTracker/Models/StockTicker.swift",
    "StockTracker/Models/PriceBar.swift",
    "StockTracker/Models/Quote.swift",
    "StockTracker/Models/PortfolioHolding.swift",
    "StockTracker/Services/FinnhubService.swift",
    "StockTracker/Services/YahooFinanceService.swift",
    "StockTracker/Services/PlaidService.swift",
    "StockTracker/ViewModels/WatchlistViewModel.swift",
    "StockTracker/ViewModels/ChartViewModel.swift",
    "StockTracker/ViewModels/PortfolioViewModel.swift",
    "StockTracker/Views/ContentView.swift",
    "StockTracker/Views/WatchlistView.swift",
    "StockTracker/Views/StockDetailView.swift",
    "StockTracker/Views/PortfolioView.swift",
    "StockTracker/Views/AddTickerView.swift",
    "StockTracker/Views/PlaidLinkView.swift",
    "StockTracker/Views/SettingsView.swift",
    "StockTracker/Utilities/MovingAverageCalculator.swift",
    "StockTracker/Utilities/KeychainHelper.swift",
]

# Files referenced in the project navigator but NOT added to a build phase.
# Info.plist is handled by INFOPLIST_FILE build setting, not Copy Bundle Resources.
PROJECT_ONLY_FILES = [
    "StockTracker/Resources/Info.plist",
]

RESOURCE_FILES: list[str] = []  # No extra bundle resources at this time

# Groups: key = logical path prefix used for membership tests
SUBGROUP_DEFS = [
    ("Models",     "StockTracker/Models/"),
    ("Services",   "StockTracker/Services/"),
    ("ViewModels", "StockTracker/ViewModels/"),
    ("Views",      "StockTracker/Views/"),
    ("Utilities",  "StockTracker/Utilities/"),
    ("Resources",  "StockTracker/Resources/"),
]

# ---------------------------------------------------------------------------
# Top-level UUIDs
# ---------------------------------------------------------------------------

U = {
    "project":        uid("project_root_obj"),
    "main_group":     uid("main_group"),
    "products_group": uid("products_group"),
    "st_group":       uid("stocktracker_group"),
    "target":         uid("target_stocktracker"),
    "sources_phase":  uid("sources_build_phase"),
    "frameworks_phase": uid("frameworks_build_phase"),
    "resources_phase":  uid("resources_build_phase"),
    "proj_cfglist":   uid("project_config_list"),
    "tgt_cfglist":    uid("target_config_list"),
    "proj_debug":     uid("project_debug_config"),
    "proj_release":   uid("project_release_config"),
    "tgt_debug":      uid("target_debug_config"),
    "tgt_release":    uid("target_release_config"),
    "product_ref":    uid("product_file_ref"),
}

for name, _ in SUBGROUP_DEFS:
    U[f"group_{name}"] = uid(f"group_{name}")


def fref(path): return uid(f"fileref_{path}")
def bfile(path): return uid(f"buildfile_{path}")


def file_type(path):
    return {".swift": "sourcecode.swift", ".plist": "text.plist.xml",
            ".html": "text.html", ".entitlements": "text.xml"}.get(Path(path).suffix, "text")


# ---------------------------------------------------------------------------
# pbxproj generator
# ---------------------------------------------------------------------------

def gen():
    L = []

    def w(*args): L.append("\t".join(args))
    def w0(s=""): L.append(s)

    w0("// !$*UTF8*$!")
    w0("{")
    w0("\tarchiveVersion = 1;")
    w0("\tclasses = {")
    w0("\t};")
    w0("\tobjectVersion = 56;")
    w0("\tobjects = {")
    w0()

    all_build_files = SOURCE_FILES + RESOURCE_FILES   # files that go into build phases
    all_ref_files   = all_build_files + PROJECT_ONLY_FILES  # all files that need a PBXFileReference

    # ------------------------------------------------------------------
    # PBXBuildFile  (only built files, not project-only references)
    # ------------------------------------------------------------------
    w0("/* Begin PBXBuildFile section */")
    for f in all_build_files:
        phase = "Sources" if f in SOURCE_FILES else "Resources"
        name  = Path(f).name
        w0(f"\t\t{bfile(f)} /* {name} in {phase} */ = "
           f"{{isa = PBXBuildFile; fileRef = {fref(f)} /* {name} */; }};")
    w0("/* End PBXBuildFile section */")
    w0()

    # ------------------------------------------------------------------
    # PBXFileReference  (all files including project-navigator-only)
    # ------------------------------------------------------------------
    w0("/* Begin PBXFileReference section */")
    w0(f"\t\t{U['product_ref']} /* StockTracker.app */ = "
       "{isa = PBXFileReference; explicitFileType = wrapper.application; "
       "includeInIndex = 0; path = StockTracker.app; sourceTree = BUILT_PRODUCTS_DIR; };")
    for f in all_ref_files:
        name  = Path(f).name
        ftype = file_type(f)
        w0(f"\t\t{fref(f)} /* {name} */ = "
           f"{{isa = PBXFileReference; lastKnownFileType = {ftype}; "
           f"path = {name}; sourceTree = \"<group>\"; }};")
    w0("/* End PBXFileReference section */")
    w0()

    # ------------------------------------------------------------------
    # PBXFrameworksBuildPhase
    # ------------------------------------------------------------------
    w0("/* Begin PBXFrameworksBuildPhase section */")
    w0(f"\t\t{U['frameworks_phase']} /* Frameworks */ = {{")
    w0("\t\t\tisa = PBXFrameworksBuildPhase;")
    w0("\t\t\tbuildActionMask = 2147483647;")
    w0("\t\t\tfiles = (")
    w0("\t\t\t);")
    w0("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w0("\t\t};")
    w0("/* End PBXFrameworksBuildPhase section */")
    w0()

    # ------------------------------------------------------------------
    # PBXGroup
    # ------------------------------------------------------------------
    w0("/* Begin PBXGroup section */")

    # Main group
    w0(f"\t\t{U['main_group']} = {{")
    w0("\t\t\tisa = PBXGroup;")
    w0("\t\t\tchildren = (")
    w0(f"\t\t\t\t{U['st_group']} /* StockTracker */,")
    w0(f"\t\t\t\t{U['products_group']} /* Products */,")
    w0("\t\t\t);")
    w0("\t\t\tsourceTree = \"<group>\";")
    w0("\t\t};")

    # Products group
    w0(f"\t\t{U['products_group']} /* Products */ = {{")
    w0("\t\t\tisa = PBXGroup;")
    w0("\t\t\tchildren = (")
    w0(f"\t\t\t\t{U['product_ref']} /* StockTracker.app */,")
    w0("\t\t\t);")
    w0("\t\t\tname = Products;")
    w0("\t\t\tsourceTree = \"<group>\";")
    w0("\t\t};")

    # StockTracker root group children
    root_children = [
        f"{fref('StockTracker/StockTrackerApp.swift')} /* StockTrackerApp.swift */,",
    ]
    for name, _ in SUBGROUP_DEFS:
        root_children.append(f"{U[f'group_{name}']} /* {name} */,")

    w0(f"\t\t{U['st_group']} /* StockTracker */ = {{")
    w0("\t\t\tisa = PBXGroup;")
    w0("\t\t\tchildren = (")
    for c in root_children:
        w0(f"\t\t\t\t{c}")
    w0("\t\t\t);")
    w0("\t\t\tpath = StockTracker;")
    w0("\t\t\tsourceTree = \"<group>\";")
    w0("\t\t};")

    # Subgroups
    for gname, prefix in SUBGROUP_DEFS:
        members = [f for f in all_ref_files if f.startswith(prefix)]
        w0(f"\t\t{U[f'group_{gname}']} /* {gname} */ = {{")
        w0("\t\t\tisa = PBXGroup;")
        w0("\t\t\tchildren = (")
        for f in members:
            name = Path(f).name
            w0(f"\t\t\t\t{fref(f)} /* {name} */,")
        w0("\t\t\t);")
        w0(f"\t\t\tpath = {gname};")
        w0("\t\t\tsourceTree = \"<group>\";")
        w0("\t\t};")

    w0("/* End PBXGroup section */")
    w0()

    # ------------------------------------------------------------------
    # PBXNativeTarget
    # ------------------------------------------------------------------
    w0("/* Begin PBXNativeTarget section */")
    w0(f"\t\t{U['target']} /* StockTracker */ = {{")
    w0("\t\t\tisa = PBXNativeTarget;")
    w0(f"\t\t\tbuildConfigurationList = {U['tgt_cfglist']} "
       "/* Build configuration list for PBXNativeTarget \"StockTracker\" */;")
    w0("\t\t\tbuildPhases = (")
    w0(f"\t\t\t\t{U['sources_phase']} /* Sources */,")
    w0(f"\t\t\t\t{U['frameworks_phase']} /* Frameworks */,")
    w0(f"\t\t\t\t{U['resources_phase']} /* Resources */,")
    w0("\t\t\t);")
    w0("\t\t\tbuildRules = (")
    w0("\t\t\t);")
    w0("\t\t\tdependencies = (")
    w0("\t\t\t);")
    w0("\t\t\tname = StockTracker;")
    w0("\t\t\tproductName = StockTracker;")
    w0(f"\t\t\tproductReference = {U['product_ref']} /* StockTracker.app */;")
    w0("\t\t\tproductType = \"com.apple.product-type.application\";")
    w0("\t\t};")
    w0("/* End PBXNativeTarget section */")
    w0()

    # ------------------------------------------------------------------
    # PBXProject
    # ------------------------------------------------------------------
    w0("/* Begin PBXProject section */")
    w0(f"\t\t{U['project']} /* Project object */ = {{")
    w0("\t\t\tisa = PBXProject;")
    w0("\t\t\tattributes = {")
    w0("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    w0("\t\t\t\tLastSwiftUpdateCheck = 1500;")
    w0("\t\t\t\tLastUpgradeCheck = 1500;")
    w0("\t\t\t\tTargetAttributes = {")
    w0(f"\t\t\t\t\t{U['target']} = {{")
    w0("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    w0("\t\t\t\t\t};")
    w0("\t\t\t\t};")
    w0("\t\t\t};")
    w0(f"\t\t\tbuildConfigurationList = {U['proj_cfglist']} "
       "/* Build configuration list for PBXProject \"StockTracker\" */;")
    w0("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    w0("\t\t\tdevelopmentRegion = en;")
    w0("\t\t\thasScannedForEncodings = 0;")
    w0("\t\t\tknownRegions = (")
    w0("\t\t\t\ten,")
    w0("\t\t\t\tBase,")
    w0("\t\t\t);")
    w0(f"\t\t\tmainGroup = {U['main_group']};")
    w0(f"\t\t\tproductRefGroup = {U['products_group']} /* Products */;")
    w0("\t\t\tprojectDirPath = \"\";")
    w0("\t\t\tprojectRoot = \"\";")
    w0("\t\t\ttargets = (")
    w0(f"\t\t\t\t{U['target']} /* StockTracker */,")
    w0("\t\t\t);")
    w0("\t\t};")
    w0("/* End PBXProject section */")
    w0()

    # ------------------------------------------------------------------
    # PBXResourcesBuildPhase
    # ------------------------------------------------------------------
    w0("/* Begin PBXResourcesBuildPhase section */")
    w0(f"\t\t{U['resources_phase']} /* Resources */ = {{")
    w0("\t\t\tisa = PBXResourcesBuildPhase;")
    w0("\t\t\tbuildActionMask = 2147483647;")
    w0("\t\t\tfiles = (")
    for f in RESOURCE_FILES:
        name = Path(f).name
        w0(f"\t\t\t\t{bfile(f)} /* {name} in Resources */,")
    w0("\t\t\t);")
    w0("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w0("\t\t};")
    w0("/* End PBXResourcesBuildPhase section */")
    w0()

    # ------------------------------------------------------------------
    # PBXSourcesBuildPhase
    # ------------------------------------------------------------------
    w0("/* Begin PBXSourcesBuildPhase section */")
    w0(f"\t\t{U['sources_phase']} /* Sources */ = {{")
    w0("\t\t\tisa = PBXSourcesBuildPhase;")
    w0("\t\t\tbuildActionMask = 2147483647;")
    w0("\t\t\tfiles = (")
    for f in SOURCE_FILES:
        name = Path(f).name
        w0(f"\t\t\t\t{bfile(f)} /* {name} in Sources */,")
    w0("\t\t\t);")
    w0("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w0("\t\t};")
    w0("/* End PBXSourcesBuildPhase section */")
    w0()

    # ------------------------------------------------------------------
    # XCBuildConfiguration
    # ------------------------------------------------------------------
    w0("/* Begin XCBuildConfiguration section */")

    # --- Project Debug ---
    w0(f"\t\t{U['proj_debug']} /* Debug */ = {{")
    w0("\t\t\tisa = XCBuildConfiguration;")
    w0("\t\t\tbuildSettings = {")
    w0("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
    w0("\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;")
    w0("\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
    w0("\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;")
    w0("\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;")
    w0("\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (\"DEBUG=1\", \"$(inherited)\",);")
    w0("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 13.0;")
    w0("\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;")
    w0("\t\t\t\tSDKROOT = macosx;")
    w0("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;")
    w0("\t\t\t};")
    w0("\t\t\tname = Debug;")
    w0("\t\t};")

    # --- Project Release ---
    w0(f"\t\t{U['proj_release']} /* Release */ = {{")
    w0("\t\t\tisa = XCBuildConfiguration;")
    w0("\t\t\tbuildSettings = {")
    w0("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
    w0("\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";")
    w0("\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
    w0("\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;")
    w0("\t\t\t\tGCC_OPTIMIZATION_LEVEL = s;")
    w0("\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (\"$(inherited)\",);")
    w0("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 13.0;")
    w0("\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;")
    w0("\t\t\t\tSDKROOT = macosx;")
    w0("\t\t\t};")
    w0("\t\t\tname = Release;")
    w0("\t\t};")

    def target_config(config_uid, name):
        is_debug = name == "Debug"
        w0(f"\t\t{config_uid} /* {name} */ = {{")
        w0("\t\t\tisa = XCBuildConfiguration;")
        w0("\t\t\tbuildSettings = {")
        w0("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
        w0("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
        w0("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
        w0("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
        w0("\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;")
        w0(f"\t\t\t\tDEBUG_INFORMATION_FORMAT = {'dwarf' if is_debug else 'dwarf-with-dsym'};")
        w0("\t\t\t\tDEVELOPMENT_TEAM = \"\";")
        w0("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
        w0("\t\t\t\tENABLE_HARDENED_RUNTIME = NO;")
        w0(f"\t\t\t\tENABLE_TESTABILITY = {'YES' if is_debug else 'NO'};")
        w0("\t\t\t\tINFOPLIST_FILE = StockTracker/Resources/Info.plist;")
        w0("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
        w0("\t\t\t\t\t\"$(inherited)\",")
        w0("\t\t\t\t\t\"@executable_path/../Frameworks\",")
        w0("\t\t\t\t);")
        w0("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 13.0;")
        w0("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = \"com.stocktracker.app\";")
        w0("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
        w0("\t\t\t\tSDKROOT = macosx;")
        w0("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
        w0(f"\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = {'-Onone' if is_debug else '-O'};")
        w0("\t\t\t\tSWIFT_VERSION = 5.0;")
        w0("\t\t\t};")
        w0(f"\t\t\tname = {name};")
        w0("\t\t};")

    target_config(U["tgt_debug"],   "Debug")
    target_config(U["tgt_release"], "Release")

    w0("/* End XCBuildConfiguration section */")
    w0()

    # ------------------------------------------------------------------
    # XCConfigurationList
    # ------------------------------------------------------------------
    w0("/* Begin XCConfigurationList section */")

    w0(f"\t\t{U['proj_cfglist']} /* Build configuration list for PBXProject \"StockTracker\" */ = {{")
    w0("\t\t\tisa = XCConfigurationList;")
    w0("\t\t\tbuildConfigurations = (")
    w0(f"\t\t\t\t{U['proj_debug']} /* Debug */,")
    w0(f"\t\t\t\t{U['proj_release']} /* Release */,")
    w0("\t\t\t);")
    w0("\t\t\tdefaultConfigurationIsVisible = 0;")
    w0("\t\t\tdefaultConfigurationName = Release;")
    w0("\t\t};")

    w0(f"\t\t{U['tgt_cfglist']} /* Build configuration list for PBXNativeTarget \"StockTracker\" */ = {{")
    w0("\t\t\tisa = XCConfigurationList;")
    w0("\t\t\tbuildConfigurations = (")
    w0(f"\t\t\t\t{U['tgt_debug']} /* Debug */,")
    w0(f"\t\t\t\t{U['tgt_release']} /* Release */,")
    w0("\t\t\t);")
    w0("\t\t\tdefaultConfigurationIsVisible = 0;")
    w0("\t\t\tdefaultConfigurationName = Release;")
    w0("\t\t};")

    w0("/* End XCConfigurationList section */")
    w0()

    # Close objects + root
    w0("\t};")
    w0(f"\trootObject = {U['project']} /* Project object */;")
    w0("}")

    return "\n".join(L)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    script_dir = Path(__file__).parent.resolve()
    xcodeproj_dir = script_dir / "StockTracker.xcodeproj"
    xcodeproj_dir.mkdir(exist_ok=True)

    pbxproj_path = xcodeproj_dir / "project.pbxproj"
    pbxproj_path.write_text(gen(), encoding="utf-8")

    print(f"✅  Generated {pbxproj_path}")
    print()
    print("Next steps:")
    print("  1.  open StockTracker.xcodeproj")
    print("  2.  In Xcode → Signing & Capabilities, set your Development Team")
    print("  3.  Press Cmd+R to build and run")
    print()
    print("First-time setup inside the app:")
    print("  • Settings tab → paste your Finnhub API key (free at https://finnhub.io/register)")
    print("  • Portfolio tab → enter your Plaid credentials to connect SoFi")
