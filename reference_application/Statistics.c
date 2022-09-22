#include "Statistics.h"


uint64_t StatisticsReadCounter[NUM_OF_SYMBOLS] = {0};
uint64_t StatisticsWriteCounter[NUM_OF_SYMBOLS] = {0};


double CalculateAverageCodewordLength() {

    uint64_t inputFileBits = 0;
    uint64_t outputFileBits = 0;

    for (uint16_t symbol = 0; symbol < NUM_OF_SYMBOLS; ++symbol) {
        inputFileBits += StatisticsReadCounter[symbol];
        outputFileBits += StatisticsWriteCounter[symbol];
    }

    return 8 * ((double)outputFileBits / inputFileBits);

}

double CalculateCompressionRatio() {

    uint64_t inputFileBits = 0;
    uint64_t outputFileBits = 0;

    for (uint16_t symbol = 0; symbol < NUM_OF_SYMBOLS; ++symbol) {
        inputFileBits += StatisticsReadCounter[symbol];
        outputFileBits += StatisticsWriteCounter[symbol];
    }

    return (double)outputFileBits / inputFileBits;

}

double CalculateCompressionRatioWithSemiadaptiveModelOverhead() {

    uint64_t inputFileBits = 0;
    uint64_t outputFileBits = 0;

    outputFileBits += NUM_OF_SYMBOLS * 32;  // semiadaptive model overhead

    for (uint16_t symbol = 0; symbol < NUM_OF_SYMBOLS; ++symbol) {
        inputFileBits += StatisticsReadCounter[symbol];
        outputFileBits += StatisticsWriteCounter[symbol];
    }

    return (double)outputFileBits / inputFileBits;

}

double CalculateSpaceSaving() {

    uint64_t inputFileBits = 0;
    uint64_t outputFileBits = 0;

    for (uint16_t symbol = 0; symbol < NUM_OF_SYMBOLS; ++symbol) {
        inputFileBits += StatisticsReadCounter[symbol];
        outputFileBits += StatisticsWriteCounter[symbol];
    }

    return 1 - ((double)outputFileBits / inputFileBits);

}

double CalculateSpaceSavingWithSemiadaptiveModelOverhead() {

    uint64_t inputFileBits = 0;
    uint64_t outputFileBits = 0;

    outputFileBits += NUM_OF_SYMBOLS * 32; // semiadaptive model overhead

    for (uint16_t symbol = 0; symbol < NUM_OF_SYMBOLS; ++symbol) {
        inputFileBits += StatisticsReadCounter[symbol];
        outputFileBits += StatisticsWriteCounter[symbol];
    }

    return 1 - ((double)outputFileBits / inputFileBits);

}
