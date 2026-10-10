cmake_minimum_required(VERSION 3.16)
set(CMAKE_OSX_DEPLOYMENT_TARGET 10.9 CACHE STRING "")
set(CMAKE_OSX_ARCHITECTURES x86_64 CACHE STRING "")
project(RipgrepUpdater LANGUAGES OBJC)
find_package(MavericksShipyard REQUIRED)
include(Mavericks)
include(MavericksSparkle)
mavericks_resolve_version(MAV_RG_VERSION)
# spec: updater/ICON-CREDIT.txt -- the generic icon on purpose, with its reason and its exit
mavericks_add_updater_app(
  PRODUCT rg
  PRODUCT_NAME "Mavericks ripgrep"
  VERSION "${MAV_RG_VERSION}"
  LOG_PREFIX "MavRipgrepUpdater"
  CONFIRM_TITLE "Mavericks ripgrep updated"
  CONFIRM_BODY "ripgrep for Mavericks in /usr/local/mavergreen/rg was updated."
  ALLOW_GENERIC
)
