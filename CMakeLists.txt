cmake_minimum_required(VERSION 3.10)

# Set the project name
project(HelloWorld)

# Specify the C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# Add the executable for the main program
add_executable(HelloWorld main.cpp)

# Enable testing
enable_testing()

# Add Google Test
# Download and unpack Google Test at configure time
include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/refs/tags/release-1.12.1.zip
)
# For Windows: Prevent overriding the parent project's compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

# Add the test executable
add_executable(unit_tests unit_tests.cpp math_operations.cpp)

# Link Google Test libraries
target_link_libraries(unit_tests gtest gtest_main)

# Add tests
add_test(NAME UnitTests COMMAND unit_tests)
