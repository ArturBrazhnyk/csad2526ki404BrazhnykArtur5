cmake_minimum_required(VERSION 3.14)

project(csad2526ki404BrazhnykArtur5 VERSION 0.1.0 LANGUAGES CXX)

# Use C++17
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Produce compile_commands.json for tooling
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Library for math operations
add_library(math_operations STATIC math_operations.cpp)
target_include_directories(math_operations PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

# Main executable
add_executable(${PROJECT_NAME} main.cpp)
target_link_libraries(${PROJECT_NAME} PRIVATE math_operations)

# Optional install rule
install(TARGETS ${PROJECT_NAME}
        RUNTIME DESTINATION bin)

# Enable testing
enable_testing()

# Bring in GoogleTest using FetchContent
include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/refs/tags/release-1.12.1.zip
)
# Prevent overriding the parent project's compiler/linker settings on Windows
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

# Unit test target
add_executable(unit_tests tests/unit_tests.cpp)
target_link_libraries(unit_tests PRIVATE math_operations GTest::gtest_main)
include(GoogleTest)
gtest_discover_tests(unit_tests)