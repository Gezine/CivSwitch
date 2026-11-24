# Options:
# CONTROLLER_TYPE: "Gamecube", "N64", "Switch" or "Macro" (default Macro)
# SWITCH_BLUETOOTH: Remove for USB
find_package(Python3 REQUIRED COMPONENTS Interpreter)
add_compile_definitions(CONTROLLER_TYPE=\"Macro\")
add_library(statusLed INTERFACE)
target_include_directories(statusLed INTERFACE ${PROJECT_SOURCE_DIR}/include)
target_link_libraries(statusLed INTERFACE pico_stdlib)
if(PICO_BOARD STREQUAL "pico_w" OR PICO_BOARD STREQUAL "pico2_w")
    target_link_libraries(statusLed INTERFACE pico_cyw43_arch_none)
endif()
add_subdirectory(otherController)
add_subdirectory(switchController)
add_subdirectory(macro)

add_executable(${CIV7_TARGET_NAME} main.cpp)
target_include_directories(${CIV7_TARGET_NAME} PUBLIC ${PROJECT_SOURCE_DIR}/include)
target_link_libraries(${CIV7_TARGET_NAME} pico_stdlib statusLed switchBluetooth switchUsb n64 gamecube Switch macro)

pico_enable_stdio_usb(${CIV7_TARGET_NAME} 0)
pico_enable_stdio_uart(${CIV7_TARGET_NAME} 1)
# picotool's uf2 convert segfaults on some hosts; the build packs the UF2
# itself from the .bin (byte-identical output, see tools/pack_uf2.py).
set(PICO_NO_UF2 1)
pico_add_extra_outputs(${CIV7_TARGET_NAME})

if(PICO_BOARD STREQUAL "pico2" OR PICO_BOARD STREQUAL "pico2_w")
    set(CIV7_UF2_FAMILY rp2350)
else()
    set(CIV7_UF2_FAMILY rp2040)
endif()
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/src/${CIV7_TARGET_NAME}.uf2
    COMMAND ${Python3_EXECUTABLE} ${PROJECT_SOURCE_DIR}/tools/pack_uf2.py
            ${CMAKE_BINARY_DIR}/src/${CIV7_TARGET_NAME}.bin
            ${CMAKE_BINARY_DIR}/src/${CIV7_TARGET_NAME}.uf2 ${CIV7_UF2_FAMILY}
    DEPENDS ${CMAKE_BINARY_DIR}/src/${CIV7_TARGET_NAME}.bin
            ${PROJECT_SOURCE_DIR}/tools/pack_uf2.py
    COMMENT "Packing ${CIV7_TARGET_NAME}.uf2 (${CIV7_UF2_FAMILY})"
    VERBATIM)
add_custom_target(${CIV7_TARGET_NAME}_uf2 ALL
    DEPENDS ${CMAKE_BINARY_DIR}/src/${CIV7_TARGET_NAME}.uf2)