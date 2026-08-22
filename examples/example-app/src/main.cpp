#include <nlohmann/json.hpp>

#include <iostream>

int main() {
    nlohmann::json doc = {
        {"name", "example-app"},
        {"version", "0.1.0"},
        {"dependencies", nlohmann::json::array({"json"})},
    };

    std::cout << doc.dump(2) << std::endl;
    return 0;
}
