#ifndef _COMMONS_H
#define _COMMONS_H


#include <stdbool.h>
#include <math.h>
#include <stdio.h>
#include <inttypes.h>
#include <stddef.h>
#include <string.h>

#define PRECISION 32                      // number of bits of precision

#define WHOLE 2147483648ULL               // 2^(PRECISION-1)
#define HALF 1073741824ULL                // 2^(PRECISION-2)
#define QUARTER 536870912ULL              // 2^(PRECISION-3)

#define NUM_OF_SYMBOLS 256                // must be less than QUARTER
#define MODEL_SIZE NUM_OF_SYMBOLS + 1     // all coded symbols + 1 EOF symbol
#define MODEL_EOF_SYMBOL 256              // determines the symbol considered as EOF
#define MODEL_MAX_FREQUENCY QUARTER - 1   // model max frequency must be less than QUARTER

#define ENCODER_BUFFER_CAPACITY 8
#define DECODER_BUFFER_CAPACITY 8192

typedef struct StatisticalModel {
    
    uint32_t frequencies[MODEL_SIZE];
    uint32_t freqBegin[MODEL_SIZE];
    uint32_t freqEnd[MODEL_SIZE];
    uint32_t totalFrequencyCounter;

} StatisticalModel;

typedef enum {
	staticModelType, semiadaptiveModelType, adaptiveModelType
} StatisticalModelType;

void UpdateStatisticalModel(StatisticalModel *model);

void HalveFrequenciesInStatisticalModel(StatisticalModel *model);

uint64_t PowerOf(uint64_t a, uint64_t n);


#endif /* _COMMONS_H */
