#ifndef CONFIGURATION_TYPES_HPP
#define CONFIGURATION_TYPES_HPP

#include <string>
#include <vector>

enum Enumeration
{
    First = 1, // To be able to detect zero vs init
    Second,
    Third
};

struct ArrayOfArrayElement
{
    Enumeration enm;
    int intg;
    std::string str;
    double fp;

    ArrayOfArrayElement()
        : enm(First) {}
};

struct ArrayElement
{
    Enumeration enm;
    int intg;
    std::string str;
    double fp;

    ArrayOfArrayElement compound;

    std::vector<int> simple_container;
    std::vector<ArrayOfArrayElement> complex_container;
    int simple_array[10];
    ArrayOfArrayElement complex_array[10];
    ArrayElement()
        : enm(First) {}
};

struct ComplexStructure
{
    Enumeration enm;
    int intg;
    std::string str;
    double fp;

    ArrayElement compound;

    std::vector<int> simple_container;
    int simple_array[10];

    std::vector<ArrayElement> vector_of_compound;
    std::vector< std::vector<ArrayElement> > vector_of_vector_of_compound;
    ArrayElement array_of_compound[10];
    std::vector<ArrayElement> array_of_vector_of_compound[10];

    ComplexStructure()
        : enm(First) {}
};

#endif
