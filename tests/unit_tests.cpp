#include "math_operations.h"
#include <cassert>
#include <iostream>

void test_add() {
    // Test case 1: Positive numbers
    assert(add(2, 3) == 5);

    // Test case 2: Negative numbers
    assert(add(-2, -3) == -5);

    // Test case 3: Mixed positive and negative numbers
    assert(add(5, -3) == 2);

    // Test case 4: Adding zero
    assert(add(0, 5) == 5);
    assert(add(5, 0) == 5);

    // Test case 5: Large numbers
    assert(add(1000000, 2000000) == 3000000);

    std::cout << "All tests passed!" << std::endl;
}

int main() {
    test_add();
    return 0;
}
