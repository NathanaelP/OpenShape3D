cmake_minimum_required(VERSION 3.25)

project(OpenShape
    VERSION 0.1.0
    DESCRIPTION "OpenShape 3D CAD Modeler"
    LANGUAGES CXX
)

# ── Language standard ─────────────────────────────────────────────────────────
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# ── Qt 6 ──────────────────────────────────────────────────────────────────────
# Qt is found via CMAKE_PREFIX_PATH, set by the setup script or CMakePresets.
find_package(Qt6 REQUIRED COMPONENTS Core Widgets)

# ── OpenCASCADE (OCCT) ────────────────────────────────────────────────────────
# Found via vcpkg toolchain (CMAKE_TOOLCHAIN_FILE in CMakePresets.json).
# M1: linked to verify the integration compiles; not called from source yet.
find_package(OpenCASCADE REQUIRED)

# ── Executable ────────────────────────────────────────────────────────────────
qt_add_executable(OpenShape
    src/main.cpp
)

target_link_libraries(OpenShape
    PRIVATE
        Qt6::Core
        Qt6::Widgets
        TKernel   # OCCT — M1 linkage smoke-test; geometry work starts in M3+
)

target_include_directories(OpenShape
    PRIVATE
        ${OpenCASCADE_INCLUDE_DIR}
)

# Platform bundle settings
set_target_properties(OpenShape PROPERTIES
    WIN32_EXECUTABLE              TRUE
    MACOSX_BUNDLE                 TRUE
    MACOSX_BUNDLE_GUI_IDENTIFIER  "com.openshape.app"
    MACOSX_BUNDLE_BUNDLE_VERSION  "${PROJECT_VERSION}"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}"
)

# ── Install (optional local install target) ───────────────────────────────────
install(TARGETS OpenShape
    BUNDLE  DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

qt_generate_deploy_app_script(
    TARGET OpenShape
    OUTPUT_SCRIPT deploy_script
    NO_UNSUPPORTED_PLATFORM_ERROR
)
install(SCRIPT ${deploy_script})
