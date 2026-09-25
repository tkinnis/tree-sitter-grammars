// A checked cast.
#define AS(T, value) static_cast<T>(value)
#define EMPTY_NAMES std::vector<std::string>{}

#pragma once
#pragma GCC diagnostic ignored "-Wunused-macros"

const char *query = R"sql(select name from accounts)sql";
