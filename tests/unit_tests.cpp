// GoogleTest-based unit tests for math_operations
#include <gtest/gtest.h>
#include <climits>
#include "../math_operations.h"

namespace {

TEST(AdditionTests, ZeroAndIdentity) {
    EXPECT_EQ(add(0, 0), 0);
    EXPECT_EQ(add(0, 5), 5);
    EXPECT_EQ(add(5, 0), 5);
}

TEST(AdditionTests, Positives) {
    EXPECT_EQ(add(1, 2), 3);
    EXPECT_EQ(add(100, 200), 300);
}

TEST(AdditionTests, NegativesAndMixed) {
    EXPECT_EQ(add(-1, -1), -2);
    EXPECT_EQ(add(-1, 1), 0);
    EXPECT_EQ(add(-100, 50), -50);
}

TEST(AdditionTests, OverflowBehavior) {
    // This test documents behaviour for large values; overflow behaviour is unspecified
    EXPECT_EQ(add(INT_MAX, 0), INT_MAX);
}

} // namespace
// *** ФУНКЦІЯ int main() ВИДАЛЕНА ЗГІДНО З ВИМОГАМИ ВИКЛАДАЧА ***