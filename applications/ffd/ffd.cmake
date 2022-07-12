#**********************
# Gather Sources
#**********************
file(GLOB_RECURSE APP_SOURCES ${CMAKE_CURRENT_LIST_DIR}/src/*.c )
set(APP_INCLUDES ${CMAKE_CURRENT_LIST_DIR}/src ${CMAKE_CURRENT_LIST_DIR}/src/ssd1306)

include(${CMAKE_CURRENT_LIST_DIR}/bsp_config/bsp_config.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/inference/inference.cmake)

#**********************
# Flags
#**********************
set(APP_COMPILER_FLAGS
    -Os
    -g
    -report
    -fxscope
    -mcmodel=large
    -Wno-xcore-fptrgroup
    ${CMAKE_CURRENT_LIST_DIR}/src/config.xscope
)

set(APP_COMPILE_DEFINITIONS
    DEBUG_PRINT_ENABLE=1
    PLATFORM_USES_TILE_0=1
    PLATFORM_USES_TILE_1=1

    QSPI_FLASH_FILESYSTEM_START_ADDRESS=0x200000
)

set(APP_LINK_OPTIONS
    -report
    ${CMAKE_CURRENT_LIST_DIR}/src/config.xscope
)

set(APP_COMMON_LINK_LIBRARIES
    sln_voice::app::ffd::inference_engine::wanson
    avona::agc
    avona::ic
    avona::ns
    avona::vad
)

#**********************
# Tile Targets
#**********************
set(TARGET_NAME tile0_application_ffd)
add_executable(${TARGET_NAME} EXCLUDE_FROM_ALL)
target_sources(${TARGET_NAME} PUBLIC ${APP_SOURCES})
target_include_directories(${TARGET_NAME} PUBLIC ${APP_INCLUDES})
target_compile_definitions(${TARGET_NAME} PUBLIC ${APP_COMPILE_DEFINITIONS} THIS_XCORE_TILE=0)
target_compile_options(${TARGET_NAME} PRIVATE ${APP_COMPILER_FLAGS})
target_link_libraries(${TARGET_NAME} PUBLIC ${APP_COMMON_LINK_LIBRARIES} sln_voice::app::ffd::xk_voice_l71)
target_link_options(${TARGET_NAME} PRIVATE ${APP_LINK_OPTIONS})
unset(TARGET_NAME)

set(TARGET_NAME tile1_application_ffd)
add_executable(${TARGET_NAME} EXCLUDE_FROM_ALL)
target_sources(${TARGET_NAME} PUBLIC ${APP_SOURCES})
target_include_directories(${TARGET_NAME} PUBLIC ${APP_INCLUDES})
target_compile_definitions(${TARGET_NAME} PUBLIC ${APP_COMPILE_DEFINITIONS} THIS_XCORE_TILE=1)
target_compile_options(${TARGET_NAME} PRIVATE ${APP_COMPILER_FLAGS})
target_link_libraries(${TARGET_NAME} PUBLIC ${APP_COMMON_LINK_LIBRARIES} sln_voice::app::ffd::xk_voice_l71)
target_link_options(${TARGET_NAME} PRIVATE ${APP_LINK_OPTIONS} )
unset(TARGET_NAME)

#**********************
# Merge binaries
#**********************
merge_binaries(application_ffd tile0_application_ffd tile1_application_ffd 1)

#**********************
# Create run and debug targets
#**********************
create_run_target(application_ffd)
create_debug_target(application_ffd)
create_flash_app_target(application_ffd)

#**********************
# Create filesystem support targets
#**********************
if(${CMAKE_HOST_SYSTEM_NAME} STREQUAL Windows)
    add_custom_command(
        OUTPUT application_ffd.fs
        COMMAND
        DEPENDS application_ffd
        COMMENT
            "Create filesystem"
        WORKING_DIRECTORY
            ${CMAKE_CURRENT_LIST_DIR}/filesystem_support
        VERBATIM
    )

    add_custom_command(
        OUTPUT application_ffd_fs_and_swmem.bin
    )
    message(WARNING "FFD Filesystem not supported on Windows")
else()
    add_custom_command(
        OUTPUT application_ffd.fs
        COMMAND bash -c "tmp_dir=$(mktemp -d) && fat_mnt_dir=$tmp_dir && mkdir -p $fat_mnt_dir && cp ./wakeup.wav $fat_mnt_dir/wakeup.wav && fatfs_mkimage --input=$tmp_dir --output=application_ffd.fs"
        COMMAND ${CMAKE_COMMAND} -E copy application_ffd.fs ${CMAKE_CURRENT_BINARY_DIR}/application_ffd.fs
        DEPENDS application_ffd
        COMMENT
            "Create filesystem"
        WORKING_DIRECTORY
            ${CMAKE_CURRENT_LIST_DIR}/filesystem_support
        VERBATIM
    )

    add_custom_command(
        OUTPUT application_ffd_fs_and_swmem.bin
        COMMAND xobjdump --strip application_ffd.xe
        COMMAND xobjdump --split application_ffd.xb
        COMMAND bash -c "cat application_ffd.fs | dd of=image_n0c0.swmem bs=1 seek=1048576 conv=notrunc"
        COMMAND ${CMAKE_COMMAND} -E copy image_n0c0.swmem application_ffd_fs_and_swmem.bin
        DEPENDS application_ffd.fs
        COMMENT
            "Extract swmem and combine with filesystem"
        VERBATIM
    )
endif()

add_custom_target(flash_fs_application_ffd
    COMMAND xflash --quad-spi-clock 50MHz --factory application_ffd.xe --boot-partition-size 0x100000 --data application_ffd_fs_and_swmem.bin
    DEPENDS application_ffd_fs_and_swmem.bin
    COMMENT
        "Flash filesystem"
    VERBATIM
)

#**********************
# Include FFD Debug and Extension targets
#**********************
include(${CMAKE_CURRENT_LIST_DIR}/ext/ffd_ext.cmake)
