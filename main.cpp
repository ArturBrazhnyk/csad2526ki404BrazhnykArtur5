#include <iostream>
#include "math_operations.h"

int main() {
    // Змінні для функції add
    int a = 5;
    int b = 10;

    // Виклик функції add
    int result = add(a, b);

    // Виведення результату
    std::cout << "Hello, World!" << std::endl;
    std::cout << "The sum of " << a << " and " << b << " is: " << result << std::endl;

    return 0;
}
