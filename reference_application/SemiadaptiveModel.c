#include "SemiadaptiveModel.h"


void SemiadaptiveModelEncoderInitializeFrequencies(StatisticalModel *model, char *inputFilePath) {

    model->totalFrequencyCounter = 0;

    // initialize all symbol frequencies to 0
    for (uint32_t i = 0; i < MODEL_SIZE; ++i) {
        model->frequencies[i] = 0;
    }

    uint16_t byte = 0;

    FILE * inputFilePointer = fopen(inputFilePath, "rb");

    // read consecutive symbols from file and increment their frequencies
    while (fread(&byte, 1, 1, inputFilePointer) == 1) {
        ++(model->frequencies[byte]);
        ++(model->totalFrequencyCounter);

        // when file size is greater than (or equal to) max frequency count, frequencies halving will be needed
        if (model->totalFrequencyCounter >= MODEL_MAX_FREQUENCY) {
            HalveFrequenciesInStatisticalModel(model);
        }
    }

    fclose(inputFilePointer);

    // initialize EOF symbol frequency to 1
    model->frequencies[MODEL_EOF_SYMBOL] = 1;
    ++(model->totalFrequencyCounter);

    // and halve frequencies if adding EOF caused reaching max frequency count
    if (model->totalFrequencyCounter >= MODEL_MAX_FREQUENCY) {
        HalveFrequenciesInStatisticalModel(model);
    }

    UpdateStatisticalModel(model);

}

void SemiadaptiveModelDecoderInitializeFrequencies(StatisticalModel *model, char *inputFilePath) {

    model->totalFrequencyCounter = 0;

    // initialize all symbol frequencies to 0
    for (uint32_t symbol = 0; symbol < MODEL_SIZE; ++symbol) {
        model->frequencies[symbol] = 0;
    }

    uint32_t frequency = 0;

    FILE * inputFilePointer = fopen(inputFilePath, "rb");

    // read frequencies counts from encoded file "header"
    for (uint16_t symbol = 0; symbol < NUM_OF_SYMBOLS; ++symbol) {
        fread(&frequency, 4, 1, inputFilePointer);
        model->frequencies[symbol] = frequency;
        model->totalFrequencyCounter += frequency;
    }

    fclose(inputFilePointer);

    // initialize EOF symbol frequency to 1
    model->frequencies[MODEL_EOF_SYMBOL] = 1;
    ++(model->totalFrequencyCounter);

    UpdateStatisticalModel(model);

}

void SemiadaptiveModelUpdateSymbolFrequency(StatisticalModel *model, uint16_t symbol) {

    --model->frequencies[symbol];
    --model->totalFrequencyCounter;

    UpdateStatisticalModel(model);

}
